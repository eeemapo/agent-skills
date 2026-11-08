---
name: homelab-llm-admin
description: Administer the homelab LLM serving stack end to end — add, remove, retune, or retire a model on a llama-swap node (lax/phx) and expose it through the LiteLLM front door (MCO), including where config files live, which edits hot-reload versus which need a compose run, matrix/concurrency and eviction rules, GGUF and docker-run stanza shapes, and virtual-key model scoping. Use when adding a model to the fleet, when a model is missing or 401/404s through ai.armadillo-hops.ts.net, when editing llama-swap or LiteLLM config, when deciding if a change needs a container restart, or when asked how models are served across lax, phx and MCO.
license: MIT
compatibility: pi on las with ssh to lax, phx and mco. Reads llama-swap and LiteLLM config on the hosts. Read-only by default; every write is called out explicitly.
metadata:
  version: "1.0"
  spec: Agent Skills 1.0
  upstream: llama-swap (mostlygeek), LiteLLM (BerriAI)
---

# Homelab LLM administration

Serving is **three layers**. A model is not "added" until it exists in layer 1
and is reachable in layer 2; layer 3 is only for secrets and stack shape.

| Layer | What it is | Where it lives | Change cost |
|---|---|---|---|
| 1. Node | `llama-swap` on `lax` or `phx` — owns the GPUs, spawns backends, swaps models | `/opt/docker/deploy/llama-swap-<node>/config/llama-cpp/config.yaml` (container: `/llama-config/config.yaml`) | **hot reload, ~2 s** |
| 2. Front door | `LiteLLM` on `MCO` — virtual keys, model scoping, budgets, spend logs | `/opt/docker/deploy/ai/config/litellm/config.yaml` on `mco` (container: `/app/config/config.yaml`) | **hot reload, ~1–2 s** |
| 3. Stack | compose files, env, mounts, images | `/opt/docker/deploy/<stack>` on the host — a git checkout of `homelab/stack-<stack>` | **restart / new container** |

Clients talk to `https://ai.armadillo-hops.ts.net` (LiteLLM). LiteLLM calls each
node's `llama-swap` over the tailnet by `<node>/<model-id>`.

## Quick reference

| Your task involves... | Read this first | Why |
|---|---|---|
| "What's served?", "what key do I use?" | [`patterns/find-models-and-credentials.md`](patterns/find-models-and-credentials.md) | Three catalogues, per-endpoint credentials, 401/403/404 triage |
| Add / remove / retune a model on a node | [`patterns/add-model-to-node.md`](patterns/add-model-to-node.md) | Stanza shapes, model dirs, matrix, reload + verify |
| Get the weights (quant choice, cache vs preseed, disk) | [`patterns/download-and-preseed-weights.md`](patterns/download-and-preseed-weights.md) | Name the quant, warm the HF cache, where files live |
| Is this file what it claims to be? | [`patterns/inspect-a-gguf.md`](patterns/inspect-a-gguf.md) | Header/metadata forensics with `scripts/gguf-inspect.py` |
| Empty answers, runaway reasoning, "thinking" knobs | [`patterns/thinking-modes.md`](patterns/thinking-modes.md) | Template vs server vs request, and where the tokens went |
| Make a model usable at `ai.armadillo-hops.ts.net` | [`patterns/expose-through-litellm.md`](patterns/expose-through-litellm.md) | `model_list` entry, hot reload, per-key scoping |
| A change to compose/env/image/mounts | [`patterns/change-the-stack.md`](patterns/change-the-stack.md) | Deploy-tree checkout + compose run, what restarts |
| Host paths, ports, vault items, matrix semantics | [`references/topology.md`](references/topology.md) | The map: who runs what, where the files are |
| Whether you can even edit/deploy something | **Access and permissions** below | ssh reach, file ownership, sudo, vault reach |
| "What key does X?" on a llama-swap node | [`references/llama-swap-config.example.yaml`](references/llama-swap-config.example.yaml) | Upstream's annotated example, vendored at our version |
| "What key does X?" in LiteLLM | [`references/litellm-config.examples.yaml`](references/litellm-config.examples.yaml) | Three upstream examples we actually match |

## Weights: one directory per model, said by absolute path

Both nodes mount `/opt/ai/models` → `/models` and every stanza names its files
(`-m` / `--mmproj` / `-md`) under `/models/llama-cpp/<model>/`. There is no
`/hf-cache` and no `/custom` mount any more (retired 2026-11-04), so download to
disk first. **Always name the specific quant file** — a bare `hf download <repo>`
pulls every quant and shard in the repo. Details, placement and traps:
[`patterns/download-and-preseed-weights.md`](patterns/download-and-preseed-weights.md).

## The two commands worth memorising

    # layer 1 — on the node, edit in place; llama-swap polls and reloads in ~2 s
    ssh phx ; $EDITOR /opt/docker/deploy/llama-swap-phx/config/llama-cpp/config.yaml

    # layer 2 — on MCO, edit in place; the LiteLLM worker reloads in ~1–2 s
    ssh mco ; $EDITOR /opt/docker/deploy/ai/config/litellm/config.yaml

Neither restarts a container and neither needs a compose run.

The node config is the stack's own git checkout, so **commit after editing**.
The bind is resolved when the container *starts*: re-materialising
`/opt/docker/deploy/<stack>` under a running container (rsync into a fresh
directory, `rm -rf` + re-clone) leaves it bound to the deleted inode —
`/llama-config` then lists empty and hot reload silently stops while the stale
in-memory config keeps serving. `docker restart <container>` restores it;
verify with `docker exec … md5sum /llama-config/config.yaml` against the host file.

## Credentials at a glance

| Endpoint | Credential | Where |
|---|---|---|
| LiteLLM `ai.` (routine) | virtual key | `HL-OPS` → `litellm-ops` (one field per key; `vault_describe` lists them) |
| a node's llama-swap | node key | `HL-SRV` → `llama-swap-phx`/`-lax` → `credential` |
| LiteLLM admin | master key | container env `LITELLM_MASTER_KEY` |
| host sudo | password | `HL-INF` → `MCO`/`LAX`/`PHX` → `password` |

Resolve with `vault_run`, reference by env-var name, never echo. Key labels are
discovered with `vault_describe`, not remembered — a renamed or added key shows up
there first. Full recipes and the 401/403/404 table:
[`patterns/find-models-and-credentials.md`](patterns/find-models-and-credentials.md).

## Access and permissions

From `las`, plain OpenSSH reaches every host over the tailnet as `sysops`,
key-based, no password and no sudo:

    ssh lax     # GPU node, utility models
    ssh phx     # GPU node, chat weights
    ssh mco     # LiteLLM front door

It is ordinary `sshd` over the tailnet, **not** `tailscale ssh`: the latter fails
against the `tag:container` devices (`502` then connection refused on :22) even
though `ssh <host>` works. Use `ssh`.

`sysops` is in the `docker` group on every host, so `docker ps/logs/inspect/exec`
work without elevation. `sudo` exists everywhere but **prompts for a password** —
treat anything root as a request to the user, never a routine step.

| Path | Owner | Writable by `sysops` | Consequence |
|---|---|---|---|
| `lax:/opt/docker/deploy/llama-swap-lax/config/llama-cpp/` | sysops | **yes**, dir + file | edit, commit, atomic save all fine |
| `phx:/opt/docker/deploy/llama-swap-phx/config/llama-cpp/` | sysops | **yes**, dir + file | same |
| `mco:/opt/docker/deploy/ai/config/litellm/` | sysops | **yes** | edit, commit, atomic save all fine |

All four are now writable, so edit in place *or* write-then-rename — both work.
Two host-specific habits remain:

- **`unfuck`** is a `sysops` bash alias on the hosts: `cd <dir> && unfuck` runs
  `chown -R $USER:$USER . && chmod -R 755 . && chmod g+s .`. It needs sudo. Note
  that `chmod -R 755` also marks **regular files** executable — after running it,
  drop config files back to `644`.
- **Metadata counts as a change.** LiteLLM's watcher fires on inotify attribute
  events, so a `chown`/`chmod` on `config.yaml` triggers a worker reload just like
  an edit. Harmless, but the health endpoint returns nothing for a second or two.

**The routine loop needs no escalation at all** — add/retune/retire a model, expose
it, reload, verify. `sysops` owns every path involved (`/opt/ai` on both nodes is
`sysops:sysops` setgid, so even a new model tree is just `mkdir`), and the `pi`
virtual key that proves it live comes from the default `HL-OPS` reach.

What **does** still need more, and from where:

| Task | Needs | Where it comes from |
|---|---|---|
| root on a host (packages, users, root-owned paths, daemon config) | `sudo` | `HL-INF` (`MCO`/`LAX`/`PHX`) — **per-session** escalation |
| call a node's API with its own key instead of via LiteLLM | node keys | `HL-SRV` — outside the default reach |
| any vault **write** | manage mode | user arms `/vault manage` |
| layer-3 change to a stack | none beyond `sysops` + docker | the deploy tree is a git checkout you own |

Two honest caveats: the `docker` group is root-equivalent (`docker run -v /:/host`),
so "no sudo" is not "no authority"; and an escalated vault reach is **memory-only
for that session** — a fresh session is back to `HL-OPS` alone and the sudo item
is out of reach again.

Secrets: the vault's default reach is `HL-OPS` **read-only** with manage OFF, so
`vault_set`/`vault_new`/`vault_edit` are refused until the user arms
`/vault manage`. `HL-SRV` / `HL-INF` are outside the default reach by design —
naming them is an escalation to ask for, not a routine lookup.

There is **no orchestration plane** (Komodo was decommissioned 2026-11-02):
every stack is a git checkout on its host and `docker compose` there is the
supported path. A stack change is an edit in that checkout plus a compose run;
nothing else has to be asked for — see
[`patterns/change-the-stack.md`](patterns/change-the-stack.md).

## Decision flow

1. **Does the node already serve it?** Ask the node, don't guess:
   `bash <skill>/scripts/fleet-status.sh`.
2. **Not on the node →** add a stanza (layer 1), then verify with
   `/v1/models` on that node.
3. **On the node, invisible on `ai.` →** add a `model_list` entry (layer 2).
4. **Visible but 401/403 →** the client's virtual key does not scope it; see
   [`patterns/expose-through-litellm.md`](patterns/expose-through-litellm.md).
5. **Only then** consider layer 3 — and only if the *container* is wrong
   (missing mount, missing env, new image), never for a model entry.

## Verification, in order

    bash <skill>/scripts/fleet-status.sh                 # what each node + LiteLLM serve
    bash <skill>/scripts/check-llamaswap-config.py <fg>  # lint a llama-swap YAML before applying
    curl -s -H "Authorization: Bearer $KEY" https://ai.armadillo-hops.ts.net/v1/models | jq -r '.data[].id'

A real end-to-end check is one chat completion through `ai.` with the model id
`<node>/<model-id>` — a model in `/v1/models` is a catalog entry, not proof the
backend starts.

## Upstream references, vendored

Both are pinned to the version we run and carry provenance + hash in their
header; neither is deployed.

- `references/llama-swap-config.example.yaml` — upstream `docs/config.example.yaml`
  at **tag v268** (the tag both nodes report), ~950 lines, every key documented
  with default and meaning. Note the one divergence the header calls out: it
  shows the newer `routing.router…` matrix form, our nodes use the older
top-level `matrix:` block.
- `references/litellm-config.examples.yaml` — LiteLLM has **no** single annotated
  config; it keeps ~30 narrow examples. Three are vendored verbatim
  (`simple_config`, `store_model_db_config`, `pass_through_config`), with the
  docs URL for the full settings matrix.

## Gotchas

- **An empty answer is usually a thinking budget, not a broken model.** If
  `finish_reason` is `length` with empty `content`, the reasoning consumed
  `max_tokens`; see [`patterns/thinking-modes.md`](patterns/thinking-modes.md).
- **Config ≠ residency.** A stanza only describes how to start a backend. Models
  load on first request and unload after `ttl`/`unloadTimeout`.
- **`/v1/models` counts aliases too.** The nodes set `includeAliasesInList:
  true`, so the list can be longer than the number of stanzas. Count stanzas in
  the config for the model count; use `running` for what is actually loaded.
- **A model in no matrix set can only run alone.** That is the safe default for
  a big model, and the reason a two-GPU model alongside a 9B will evict it.
- **`startPort: 10001`** — llama-swap assigns `${PORT}` per model. Backends
  spawned with `docker run` must join the node's tailscale netns
  (`--network container:${env.LLAMA_SWAP_TS_CTR}`) so `127.0.0.1:${PORT}` is
  shared; that env var exists on `phx` only, and only `phx` mounts the docker
  socket + CLI.
- **`-hf` downloads lazily at load time.** A stanza pointing at an uncached repo
  turns a first request into a multi-GB pull that usually outlives the health
  check. Preseed the cache instead of learning this the hard way.
- **First load can outlast the health check.** Global `healthCheckTimeout` is
  300 s; a cold 30–60 GB model needs a per-model override (`healthCheckTimeout:
  900`) or llama-swap reports `health check timed out` and kills a load that
  would have succeeded.
- **LiteLLM's DB overlays the YAML.** With `store_model_in_db: true`, values for
  `general_settings`, `router_settings`, `litellm_settings` and
  `environment_variables` come from Postgres and **win over the file**. Editing
  those in YAML appears to do nothing.
- **`public` is the only scoped key.** Keys with `models: []` reach everything;
  `public` carries an explicit list, so a new model is invisible to it until
  added.
- **Secrets are deploy-time.** `LLAMA_SWAP_LAX_KEY`, `LLAMA_SWAP_PHX_KEY`,
  `OPENROUTER_API_KEY`, `LITELLM_MASTER_KEY` and the DB/Redis passwords are
  injected by the stack's `op run` wrapper — they are not in the repo and not in
  the YAML you hot-edit.
- **Don't hand-manage backend containers.** llama-swap names them
  `${MODEL_ID}` and removes them with `--rm`; `docker stop` on one is a
  debugging move, not administration.

## What NOT to do here

- Do not `docker run` a llama.cpp/vLLM container by hand as a lasting service —
  it goes in a stanza (layer 1) or a deployment/stack (layer 3).
- Do not edit the config **inside** the container; the deploy-tree file
  (`/opt/docker/deploy/llama-swap-<node>/config/llama-cpp/config.yaml`) is the
  bind-mounted source, and it is a git checkout — commit there.
- Do not "fix" a missing model by restarting llama-swap or LiteLLM; both watch
  their config. Restarting only helps when the *container* changed.
- Do not go looking for Komodo: it is gone (decommissioned 2026-11-02). The
  deploy tree on the host is the state.
- Do not add a model to one node and assume the other serves it; `lax` and `phx`
  have independent configs and different GPUs.
