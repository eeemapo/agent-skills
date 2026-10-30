# Add, change or remove a model on a llama-swap node

> **Example ids in this file are illustrative.** No model named here is
> guaranteed to exist right now — stanzas get renamed and retired. The live
> roster is `scripts/fleet-status.sh` (or the node's own `/v1/models`). Read the
> shapes, substitute the real ids.

Layer 1. One file per host, bind-mounted into the container:

    lax:  /opt/ai/config/llama-swap/config.yaml   (container: /llama-config/config.yaml)
    phx:  /opt/ai/config/llama-swap/config.yaml

The container runs `-config … -watch-config`, so a saved edit is picked up in
about 2 s. **No restart, no Komodo deploy.** Back up first:

    ssh phx 'cp -a /opt/ai/config/llama-swap/config.yaml \
             /opt/ai/config/llama-swap/config.yaml.bak.$(date +%Y%m%d-%H%M%S)'

## Step 1 — pick the stanza shape

| Backend | Shape | Use when |
|---|---|---|
| llama.cpp | `cmd: > llama-server …` | a GGUF from the HF hub or a local path |
| sibling container | `cmd: \| docker run …` | the backend is its own image (Strata, vLLM/HyperQwen) |
| remote | `proxy: http://…` + `useModelName` | an OpenAI-compatible server you do not spawn |

### llama.cpp stanza (the common case)

```yaml
  "My-Model":
    cmd: >
      llama-server
      --host 127.0.0.1
      --port ${PORT}
      -hf <org>/<repo>-GGUF
      -hff <file.gguf>
      --n-gpu-layers 999
      --flash-attn on
      --ctx-size 65536
      --jinja
      --parallel 1
    ttl: 3600
    capabilities:
      in: [text]
      out: [text]
      context: 65536
      tools: true
    aliases: ["mymodel"]
```

- `-hf`/`-hff` load from the HF cache mount (`/hf-cache`) and **download lazily
  at load time** — preseed the cache first, and name the exact quant file
  ([`download-and-preseed-weights.md`](download-and-preseed-weights.md)). A file
  already on disk is passed by absolute path instead (`-m /models/<file>.gguf`).
- `${PORT}` is assigned by llama-swap from `startPort: 10001`. Never hardcode.
- `capabilities.context` must match `--ctx-size`; clients trust the former.
- `ttl` (seconds idle) and `unloadTimeout` (grace before kill) decide eviction.

### Sibling-container stanza (Strata, vLLM/HyperQwen)

`phx` only — it is the node with `/var/run/docker.sock` and the docker CLI
mounted, plus `LLAMA_SWAP_TS_CTR` in its environment.

```yaml
  "Qwen3.8-27B-vLLM":
    checkEndpoint: /health
    healthCheckTimeout: 900          # cold vLLM start ~2-3 min > global 300 s
    useModelName: "qwen3.8-27b"      # the name the backend itself accepts
    cmd: |
      docker run --name ${MODEL_ID} --init --rm --stop-timeout 120
      --network container:${env.LLAMA_SWAP_TS_CTR}
      --gpus all --ipc host --ulimit memlock=-1:-1
      -e PORT=${PORT}
      …
      ghcr.io/<image>@sha256:<digest>
    cmdStop: docker stop ${MODEL_ID}
    unloadTimeout: 900
    ttl: 3600
    capabilities:
      in: [text]
      out: [text]
      context: 131072
      tools: true
    aliases: ["qwen3.8-27b"]
```

Rules that bite when broken:

- `--network container:${env.LLAMA_SWAP_TS_CTR}` is what shares `127.0.0.1`; a
  bridge network means the health check never passes.
- Pin the image by digest. `:latest` silently changes behaviour on the next pull.
- Leave the backend keyless and bound to `127.0.0.1` inside that shared netns,
  and let llama-swap enforce auth. A keyed backend needs
  `useModelName` + a matching client key and creates the 401 class of bug.
- `checkEndpoint: /health` for vLLM; omit for llama-server (llama-swap's default
  probe is fine).

## Step 2 — matrix (can these models coexist?)

`matrix.sets` decides co-residency; `evict_costs` decides who gets sacrificed.

```yaml
matrix:
  vars:  { g0: gemma-4-E4B-it-0, … }
  evict_costs: { g0: 50, Qwen3.8-27B: 200 }
  sets:
    card-0: "g0 | q0"                        # one at a time on card 0
    card-0_1: "Cyber-Tiel-Coder | Qwen3.8-27B | Qwen3.8-27B-vLLM"
    sys: "+card-0_1 | (+card-0 & +card-1)"
```

- `|` alternatives, `&` must coexist, `+name` include another set, `()` group.
- **A model in no set can only run alone** — a valid, deliberate choice for a
  big model, but it means it evicts everything when it loads.
- Adding a model that spans both GPUs *must* go in a set that includes it, or it
  will fight the per-card models for VRAM.
- Register a costly cold start in `evict_costs` so the solver avoids evicting it.
- The vendored example in `../references/llama-swap-config.example.yaml` shows a
  newer `routing.router.use: matrix` form. Both work on v268; ours is the older
  top-level `matrix:` and there is no reason to migrate it mid-change.

## Step 3 — apply and verify

    # 1. lint before you save over the live file
    bash <skill>/scripts/check-llamaswap-config.py /tmp/config.yaml

    # 2. save in place, then watch the reload
    ssh phx 'docker logs --tail 20 llama-swap-phx-app-1 | grep -i "config"'

    # 3. catalog
    curl -s -H "Authorization: Bearer $KEY" \
      https://llama-swap-phx.armadillo-hops.ts.net/v1/models | jq -r '.data[].id'

    # 4. real load (catalog ≠ loaded)
    curl -s -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
      https://llama-swap-phx.armadillo-hops.ts.net/v1/chat/completions \
      -d '{"model":"My-Model","messages":[{"role":"user","content":"hi"}],"max_tokens":16}'

## Step 4 — retire a model

1. Remove the stanza **and** every matrix reference (`vars` entry, `sets` leaf).
   A dangling leaf fails config load and llama-swap keeps the old config.
2. Delete the weights from the host only when nothing else references them
   (`phx`: `/opt/ai/strata/models/<name>`, `/opt/ai/hyperqwen/models`,
   `/opt/ai/nemotron/models`; `lax`: `/opt/ai/models`, `/opt/ai/custom/models`).
3. Remove the LiteLLM `model_list` entry (layer 2) — otherwise `ai.` keeps
   advertising a model that no longer starts.

## Failure signatures

| Symptom | Cause |
|---|---|
| `health check timed out after 5m0s` | cold load > `healthCheckTimeout`; raise it per model |
| model listed, request 502/timeout | backend never bound `127.0.0.1:${PORT}` (wrong network) |
| config reload does nothing | YAML did not parse; llama-swap keeps the previous config — `docker logs` says so |
| `unknown model` in matrix error | a `vars`/`sets` name that is not a real model id |
| two models keep evicting each other | they share a `|` set; give them a set that joins them (`&`) |
