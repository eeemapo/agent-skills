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

`sysops` is in `docker` (every host) and `sudo` (password required — root is
a request, not a step).

| Path | Owner | Status |
|---|---|---|
| `lax:/opt/docker/deploy/llama-swap-lax/config/llama-cpp/config.yaml` | `sysops:sysops`, dir `sysops` | fully writable; git checkout, commit after edit |
| `phx:/opt/docker/deploy/llama-swap-phx/config/llama-cpp/config.yaml` | `sysops:sysops`, dir `sysops` | same |
| `lax:/opt/ai/models`, `phx:/opt/ai/models` | `sysops:sysops`, setgid | weight trees; `mkdir` a model dir directly |
| `mco:/opt/docker/deploy/ai/config/litellm/config.yaml` | `sysops:sysops 644` | the live LiteLLM config; git checkout, commit after edit |

`/stackData/litellm/config/config.yaml` still exists on `mco` but is **not**
mounted — it is a pre-migration leftover. Editing it changes nothing; check
`docker inspect ai-litellm-1` for the real source (2026-11-07).

### The `unfuck` alias

Defined in `~/.bashrc` on the hosts (`sysops`):

```bash
alias unfuck='f(){ sudo chown -R ${1:-$USER:$USER} . && chmod -R 755 . && chmod g+s .; unset -f f; }; f'
```

It operates on the **current directory** (the optional argument is the
*owner*, not a path), and it needs sudo. Consequences worth knowing:

- `chmod -R 755` marks every **file** executable too — reset configs to `644`
  afterwards (`chmod 644 /opt/docker/deploy/ai/config/litellm/config.yaml`).
- `chmod g+s .` is **not** recursive, so only the top directory becomes setgid.
- It chowns recursively — check the scope first (`du -sh`, `ls`) on a big tree.

### sudo

The `sysops` sudo password for `mco` (and `lax`/`phx`) lives in the **`HL-INF`**
vault — items `MCO`, `LAX`, `PHX`, field `password`. `HL-INF` is outside the
default vault reach: it is an escalation the user grants (`/vault add <SA>`), not
a routine lookup. Never put the password in a command line or a log; pipe it to
`sudo -S` on stdin.

### No orchestration plane

Komodo was decommissioned **2026-11-02** (Core down, Periphery removed from every
host, `/etc/komodo` purged). Do not look for a control plane and do not trust
anything that still mentions one: each stack is a git checkout under
`/opt/docker/deploy/<stack>` and `docker compose` on the host is the supported
path. `gitea` and `op-connect` are hand-run — never "deploy" them from another
stack's compose run, and never `down -v` either.

### Vault (secrets)

| Tier | Reachable by default | Holds |
|---|---|---|
| `HL-OPS` | **yes**, read-only | `litellm-ops` (virtual keys `pi`, `public`, `work`; the OpenWebUI key is parked as `retired-openwebui`) |
| `HL-SRV` | no | per-service items (`llama-swap-lax`, `llama-swap-phx`, …) |
| `HL-INF` | no | host sudo/ssh, tailscale control plane (the Komodo key is retired) |

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
e.g. `phx/<model-id>` (illustrative). The node-level id is what appears in that node's
llama-swap config.

## Hosts

| Host | Role | GPUs | Stacks (deploy trees) |
|---|---|---|---|
| `lax` | GPU node + utility models (OCR, ASR, embeddings, doc-layout) | 2× RTX 3060 12 GB | `llama-swap-lax` |
| `phx` | GPU node, chat weights | 2× RTX 3060 12 GB | `llama-swap-phx` |
| `mco` | Front door only, no GPUs | — | `ai` (LiteLLM), `crawl4ai`, `mcp`, `monitoring`, `mail` |
| `las` | This box — agent sandbox | — | — |

Deploy trees: `/opt/docker/deploy/<stack>`; runtime state:
`/opt/docker/data/<stack>`.

## Nodes

| | `lax` | `phx` |
|---|---|---|
| tailnet host | `llama-swap-lax` | `llama-swap-phx` |
| containers | `llama-swap-lax-app-1`, `llama-swap-lax-ts-1` | `llama-swap-phx-app-1`, `llama-swap-phx-ts-1` |
| image | `ghcr.io/mostlygeek/llama-swap:unified-cuda13` | same |
| command | `-config /llama-config/config.yaml -watch-config` | same |
| config (host) | `/opt/docker/deploy/llama-swap-lax/config/llama-cpp/config.yaml` | `/opt/docker/deploy/llama-swap-phx/config/llama-cpp/config.yaml` |
| reload | file watch, ~2 s | same |
| API keys in config | `${env.LLAMA_SWAP_API_KEY}`, `${env.AI_LAX_KEY}` | `${env.LLAMA_SWAP_API_KEY}`, `${env.AI_PHX_KEY}` |
| `startPort` | 10001 | 10001 |
| docker socket | not mounted | `/var/run/docker.sock` + `/usr/bin/docker:ro` |
| sibling spawning | no | yes (`LLAMA_SWAP_TS_CTR=llama-swap-phx-ts-1`) |

### Mounts that define where weights live

`lax`

| host | container | holds |
|---|---|---|
| `/opt/ai/models` (ro) | `/models` | `llama-cpp/`, `audio-cpp/`, `vllm/`, `onnx/` |
| `/opt/docker/deploy/llama-swap-lax/config/llama-cpp` | `/llama-config` | the config |

There is no `/hf-cache` and no `/custom` mount (retired 2026-11-04): every
stanza loads **one file by absolute path** under `/opt/ai/models/llama-cpp/<model>/`.

`phx`

| host | container | holds |
|---|---|---|
| `/opt/ai/models` (rw) | `/models` | `llama-cpp/<model>/` weight trees |
| `/opt/docker/deploy/llama-swap-phx/config/llama-cpp` | `/llama-config` | the config |

No `/hf-cache` mount and no `-hf` stanzas (retired 2026-11-04): weights are plain
files under `/opt/ai/models/llama-cpp/<model>/`, passed with `-m`/`--mmproj`/`-md`.
`LLAMA_SWAP_MODELS_DIR=/opt/ai/strata` is still exported for the `docker run`
stanzas but no current stanza uses it, and `/opt/ai/strata` does not exist.

## Front door (LiteLLM, MCO)

| item | value |
|---|---|
| URL | `https://ai.armadillo-hops.ts.net` (`/ui/` = admin) |
| container | `ai-litellm-1` (shares `ai-ts-1` netns) |
| image | `docker.litellm.ai/berriai/litellm:main-stable` |
| version | whatever `main-stable` resolves to (`docker inspect` labels) |
| live config | `mco:/opt/docker/deploy/ai/config/litellm/config.yaml` → `/app/config` (git checkout) |
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
| `public` | **explicit list** — new models must be added by hand |

The key values live in the vault item `litellm-ops` (fields `pi`, `public`,
`work`, and `retired-openwebui` for the parked OpenWebUI key), never in the repo.
`vault_describe` is the authority on labels — they get renamed when keys are
parked.

## Model roster — derive it, don't remember it

This file deliberately carries **no** model list. Stanzas are renamed, added and
retired often enough that a written inventory is guaranteed to be wrong, and a
wrong inventory is worse than none: it sends you looking for something that no
longer exists, or assuming something exists that does not.

    bash <skill>/scripts/fleet-status.sh            # per-node ids + front-door ids
    bash …/service-llama-swap/scripts/llama-swap.sh models   # one node, with context

Three things that are *not* the roster, and get mistaken for it:

- **`/v1/models` includes aliases** (`includeAliasesInList: true`), so it can
  list more names than there are stanzas.
- **A front-door id is namespaced** `<node>/<model-id>`; the node's own id is the
  bare `model-id`.
- **A listed id is a catalog entry, not a running backend.** `/running` is
  residency.

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
