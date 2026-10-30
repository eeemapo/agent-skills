# Topology reference

Who runs what, where the files are, and how a request flows.

## Access matrix

### Reaching the hosts

From `las`, as `sysops`, key-based OpenSSH over the tailnet — no password, no
sudo, no jump host:

| host | reaches | notes |
|---|---|---|
| `lax` | GPU node | utility models (OCR/ASR/embeddings) |
| `phx` | GPU node | chat weights; the only node that spawns sibling containers |
| `mco` | front door | no GPUs; LiteLLM + Postgres + Redis |

`ai` (the `.ts.net` name) is **not** an ssh target — it is the tailscale
container's hostname; only :443 is served. `tailscale ssh <host>` fails against
these `tag:container` devices; plain `ssh <host>` works because sshd is reachable
over the tailnet address.

### What `sysops` may write

`sysops` is in `docker` (all three hosts) and `sudo` (password required — root is
a request, not a step).

| Path | Owner | Status |
|---|---|---|
| `lax:/opt/ai/config/llama-swap/config.yaml` | `sysops:sysops`, dir `sysops` | fully writable; backup + atomic save fine |
| `phx:/opt/ai/config/llama-swap/config.yaml` | `sysops:sysops`, dir `sysops` | same |
| `phx:/opt/ai/strata`, `/opt/ai/hyperqwen`, `/opt/ai/nemotron` | `sysops` | weights are writable |
| `mco:/stackData` | `sysops:sysops` | writable, **setgid** (`drwxr-sr-x`) |
| `mco:/stackData/litellm/config/` | `sysops:sysops 755` | writable since 2026-10-30 |
| `mco:/stackData/litellm/config/config.yaml` | `sysops:sysops 644` | editable, backup-able, atomic-save-able |

Before 2026-10-30 the `litellm/config` directory was `root:root 755`, which
blocked backups, editor swap files and write-then-rename saves; it was fixed with
the host's `unfuck` alias (see below) and the file set back to `644`.

### The `unfuck` alias

Defined in `~/.bashrc` on the hosts (`sysops`):

```bash
alias unfuck='f(){ sudo chown -R ${1:-$USER:$USER} . && chmod -R 755 . && chmod g+s .; unset -f f; }; f'
```

It operates on the **current directory** (the optional argument is the
*owner*, not a path), and it needs sudo. Consequences worth knowing:

- `chmod -R 755` marks every **file** executable too — reset configs to `644`
  afterwards (`chmod 644 /stackData/litellm/config/config.yaml`).
- `chmod g+s .` is **not** recursive, so only the top directory becomes setgid.
- It chowns recursively — check the scope first (`du -sh`, `ls`) on a big tree.

### sudo

The `sysops` sudo password for `mco` (and `lax`/`phx`) lives in the **`HL-INF`**
vault — items `MCO`, `LAX`, `PHX`, field `password`. `HL-INF` is outside the
default vault reach: it is an escalation the user grants (`/vault add <SA>`), not
a routine lookup. Never put the password in a command line or a log; pipe it to
`sudo -S` on stdin.

### Komodo

Read operations cover every stack. **Write is per-stack and per-user**: deploys
of `llama-swap-phx` work, `ai` returns `insufficient permissions: Must have at
least Write permissions`. `komodo_stack_apply` with `config.config_files` needs
Write on that stack too. A refusal here is an authorization answer, not a
malformed request — ask the user to change the grant or perform the edit.

### Vault (secrets)

| Tier | Reachable by default | Holds |
|---|---|---|
| `HL-OPS` | **yes**, read-only | `litellm-ops` (virtual key aliases `pi`, `public`, `work`, `openwebui`) |
| `HL-SRV` | no | per-service items (`llama-swap-lax`, `llama-swap-phx`, …) |
| `HL-INF` | no | host sudo/ssh, tailscale control plane, Komodo infra key |

Default reach is `HL-OPS` with manage OFF: reads and `vault_run` injection work;
any write is refused until the user arms `/vault manage`. `HL-SRV`/`HL-INF` are
scope answers, not missing items — switching tiers is the user's move.

## Request path

    client ──HTTPS──▶ ai.armadillo-hops.ts.net        (MCO, LiteLLM, :4000)
                        │  virtual key → model scope
                        ▼
                https://llama-swap-<node>.armadillo-hops.ts.net/v1
                        │  Authorization: Bearer <node key>
                        ▼
                llama-swap on <node> ──spawns──▶ backend on 127.0.0.1:${PORT}

The model id at the front door is `<node>/<model-id>`, e.g.
`phx/Qwen3.8-27B-vLLM`. The node-level id is what appears in that node's
llama-swap config.

## Hosts

| Host | Role | GPUs | Stacks (Komodo) |
|---|---|---|---|
| `lax` | GPU node + utility models (OCR, ASR, embeddings, doc-layout) | CUDA | `llama-swap-lax` |
| `phx` | GPU node, chat weights | 2× RTX 3060 12 GB | `llama-swap-phx`, plus Strata/vLLM siblings spawned by llama-swap |
| `mco` | Front door only, no GPUs | — | `ai` (LiteLLM), `crawl4ai`, `mcp`, `monitoring`, `mail` |
| `las` | This box — agent sandbox | — | — |

## Nodes

| | `lax` | `phx` |
|---|---|---|
| tailnet host | `llama-swap-lax` | `llama-swap-phx` |
| containers | `llama-swap-lax-app-1`, `llama-swap-lax-ts-1` | `llama-swap-phx-app-1`, `llama-swap-phx-ts-1` |
| image | `ghcr.io/mostlygeek/llama-swap:unified-cuda13` | same |
| command | `-config /llama-config/config.yaml -watch-config` | same |
| config (host) | `/opt/ai/config/llama-swap/config.yaml` | same path |
| reload | file watch, ~2 s | same |
| API keys in config | `${env.LLAMA_SWAP_API_KEY}`, `${env.AI_LAX_KEY}` | `${env.LLAMA_SWAP_API_KEY}`, `${env.AI_PHX_KEY}` |
| `startPort` | 10001 | 10001 |
| docker socket | not mounted | `/var/run/docker.sock` + `/usr/bin/docker:ro` |
| sibling spawning | no | yes (`LLAMA_SWAP_TS_CTR=llama-swap-phx-ts-1`) |

### Mounts that define where weights live

`lax`

| host | container | holds |
|---|---|---|
| `/opt/ai/models` | `/models` | local GGUF/model trees (`audio/`, `vllm/`) |
| `/opt/ai/custom/models` | `/custom` | unpublished files referenced by absolute path |
| `/home/sysops/.cache/huggingface/hub` | `/hf-cache` | `hf` download cache (`-hf` resolves here) |
| `/opt/ai/config/llama-swap` | `/llama-config` | the config |

`phx`

| host | container | holds |
|---|---|---|
| `/opt/ai/strata/{models,data}` | per-stanza `-v` | Strata/Momoe weights + tokenizer packs |
| `/opt/ai/hyperqwen/models` | per-stanza `-v` | Qwen3.8-27B W4A16 (`…-fast` variant) |
| `/opt/ai/nemotron/{models,data}` | per-stanza `-v` | Nemotron Bolt 74B GGUF |
| `/home/sysops/.cache/huggingface/hub` | `/hf-cache` | `-hf` cache |
| `/opt/ai/config/llama-swap` | `/llama-config` | the config |

`LLAMA_SWAP_MODELS_DIR=/opt/ai/strata` exists so docker-run stanzas can write
`${env.LLAMA_SWAP_MODELS_DIR}/models/<name>` instead of a literal path.

## Front door (LiteLLM, MCO)

| item | value |
|---|---|
| URL | `https://ai.armadillo-hops.ts.net` (`/ui/` = admin) |
| container | `ai-litellm-1` (shares `ai-ts-1` netns) |
| image | `docker.litellm.ai/berriai/litellm:main-stable` |
| version seen | v1.106.6 |
| live config | `mco:/stackData/litellm/config/config.yaml` → `/app/config` |
| reload | `--reload` + `watchfiles` on `PYTHONPATH=/watchfiles`, ~1–2 s |
| state | Postgres `litellm` (`store_model_in_db: true`), Redis for rate limits |
| upstream keys | `LLAMA_SWAP_LAX_KEY`, `LLAMA_SWAP_PHX_KEY`, `OPENROUTER_API_KEY` (deploy-time) |
| master key | `LITELLM_MASTER_KEY`, admin API + UI |

The `watchfiles` wheel is installed into the `ai_watchfiles` volume by the
`init` service (`python:3.13-slim`, `pip install --target`), because the litellm
image ships neither `pip` nor `uv`. Without it uvicorn falls back to
`StatReload`, which stat-scans every `*.py` under `/app` (~100% of a core) and
never notices the YAML.

## Virtual keys

Stored in Postgres; aliases in use:

| alias | scope |
|---|---|
| `pi` | all models (`models: []`) |
| `work` | all models |
| `openwebui` | all models |
| `public` | **explicit list** — new models must be added by hand |

The key values live in the vault item `litellm-ops` (fields `pi`, `public`,
`work`, `openwebui`), never in the repo.

## Model id inventory (as of 2026-10-30)

`lax` — `Cyber-Tiel-Coder`, `gemma-4-E4B-it-0/-1`, `Qwen3.5-9B-0/-1`,
`Qwen3.8-27B`, `audiocpp`, `PaddleOCR-VL`, `GLM-OCR`, `granite-docling-258m`,
`Unlimited-OCR`, `doc-models`, `embeddinggemma-2`, `d1-3B`

`phx` — `Cyber-Tiel-Coder`, `gemma-4-E4B-it-0/-1`, `Qwen3.5-9B-0/-1`,
`Qwen3.8-27B` (llama.cpp, 64K), `Qwen3.8-27B-vLLM` (TP=2, 128K, MTP),
`Strata-Qwen3.6-35B`, `Strata-Qwen3.8-IQ2_XS`

Re-derive with `scripts/fleet-status.sh`; treat this list as a hint, not truth.

## Matrix semantics (llama-swap routing)

The configs use the top-level `matrix:` form:

```yaml
matrix:
  vars: { g0: gemma-4-E4B-it-0 }
  evict_costs: { g0: 50, Qwen3.8-27B: 200 }
  sets: { card-0: "g0 | q0", card-0_1: "A | B", sys: "+card-0_1 | (+card-0 & +card-1)" }
```

| operator | meaning |
|---|---|
| `&` | these run together |
| `\|` | alternatives (one at a time) |
| `+name` | inline another set's expression |
| `()` | grouping |

Solver on a request for X: if running, forward; else pick the set containing X
with the lowest summed `evict_costs` of models outside it, evict those, start X.
Subsets are allowed. **A model named by no set can only run alone.**
`+auto:orphans` is available for "everything not otherwise mentioned".

llama-swap also supports a newer `routing.router.use: group|matrix|capacity`
form; these configs use the legacy top-level `matrix:` and it still works.
