# Find what is served, and get a key to call it

Two questions that come up before every other task: *what models exist right
now*, and *what credential do I hit them with*. Both have three-layer answers.

## 1. Listing models — three catalogues, three different truths

| Level | Question it answers | Command |
|---|---|---|
| node (llama-swap) | what can **this node** start? | `llama-swap.sh models` |
| front door (LiteLLM) | what can **clients** call? | `curl $LITELLM_URL/v1/models` |
| residency | what is **in VRAM right now**? | `llama-swap.sh running` |

All three at once, read-only:

    bash <skill>/scripts/fleet-status.sh        # needs LITELLM_KEY for the front-door tier

### Node level

    vault_run({
      vault: "HL-SRV", item: "llama-swap-phx",
      fields: [{name:"LLAMA_SWAP_URL",field:"base_url"},
               {name:"LLAMA_SWAP_KEY",field:"credential"}],
      command: "bash …/service-llama-swap/scripts/llama-swap.sh models"})

    # … models --count        bare number, not a line count
    # … running              loaded models + state (this is residency)
    # … profiles             configured profiles, active one
    # … logs 50              buffered backend log

Raw equivalent: `GET /v1/models` (catalog), `GET /running` (residency),
`GET /api/version`, `GET /api/profiles`.

**Gotcha — aliases inflate the catalog.** Both nodes set
`includeAliasesInList: true`, so `/v1/models` returns stanzas **plus** their
aliases. `phx` reports **13** entries for **9** stanzas (4 aliases:
`strata`, `strata128`, `qwen3.8-27b`, `qwen38-vllm`). Counting stanzas in the
config file is the only way to count models; counting `/v1/models` counts
callable names.

### Front-door level

    curl -s https://ai.armadillo-hops.ts.net/v1/models \
      -H "Authorization: Bearer $LITELLM_KEY" | jq -r '.data[].id'

Ids are `<node>/<model-id>`. **The list is per key**: `pi`/`work`/`openwebui`
see all 34, `public` sees 14 (its explicit list). An empty-looking list is
usually the wrong key, not an empty gateway.

Browsers: `https://ai.armadillo-hops.ts.net/ui/` → **Models + Endpoints** → All
Models (master key login).

### Node UI

`https://llama-swap-<node>.armadillo-hops.ts.net/ui/` exists but answers **401**
without the node's API key — it is not a public dashboard. Use the script.

## 2. Credentials — which key, from where

| You want to call | Credential | Location | In default reach? |
|---|---|---|---|
| LiteLLM at `ai.` (normal work) | virtual key | vault **`HL-OPS`** → `litellm-ops` → `pi` / `public` / `work` / `openwebui` | **yes** |
| a node's llama-swap API directly | node API key | vault **`HL-SRV`** → `llama-swap-phx` / `llama-swap-lax` → `credential` (+ `base_url`) | no — escalation |
| LiteLLM admin API / UI | master key | container env `LITELLM_MASTER_KEY` (`docker exec … printenv`) | docker group, no vault |
| sudo on a host | password | vault **`HL-INF`** → `MCO` / `LAX` / `PHX` → `password` | no — escalation |

Always resolve through `vault_run` into an env var and reference it by name;
never paste a value into chat, a command line, or a log.

    # front door (default reach — this is the routine path)
    vault_run({
      item: "litellm-ops", fields: [{name:"LITELLM_KEY",field:"pi"}],
      command: "curl -s https://ai.armadillo-hops.ts.net/v1/models -H \"Authorization: Bearer $LITELLM_KEY\""})

    # a node, keyed
    vault_run({
      vault: "HL-SRV", item: "llama-swap-lax",
      fields: [{name:"URL",field:"base_url"},{name:"KEY",field:"credential"}],
      command: "curl -s $URL/v1/models -H \"Authorization: Bearer $KEY\""})

Notes:

- The node item's `base_url` **already includes** `https://` — do not add or
  strip a scheme. When using `llama-swap.sh`, pass it as `LLAMA_SWAP_URL`; when
  curving by hand, append `/v1` or `/running`.
- **Don't need the node key?** Usually you don't. Everything the node serves is
  reachable through LiteLLM with the `HL-OPS` key, which is why the routine loop
  needs no escalation. Reach for `HL-SRV` only to bypass the front door
  (debugging a stanza, checking `/running`, reading a node's own logs endpoint).
- **Fallback if `HL-SRV` is out of reach:** the node keys are also in the
  llama-swap container's environment (`docker exec llama-swap-phx-app-1 printenv
  LLAMA_SWAP_API_KEY`). That works because `sysops` is in `docker`, but it is a
  secret-exposure path — prefer the vault, and never echo the result.
- **LiteLLM master key ≠ client key.** The master key administers the proxy
  (create/update keys, read spend); virtual keys are what clients send. Don't
  hand a client the master key.

## 3. Symptom → cause

| What you see | Cause |
|---|---|
| `401 Authentication Error, No api key passed` | no `Authorization` header at all |
| `401 Unauthorized` from LiteLLM, key present | wrong/expired virtual key |
| `401` from a node | using the LiteLLM key against `llama-swap-*` (different key space) |
| model works with `pi`, `403`/model-not-found with `public` | key scoping — add the id to `public`'s list |
| `404` at `ai.` | no `model_list` entry for that `<node>/<id>` |
| `404` at the node | no such stanza (or an alias you typed instead of the id) |
| id listed, request hangs then 502 | backend failed to start — check `docker logs ${MODEL_ID}`, then the node's stanza |
| `/v1/models` shorter than you expect | wrong key scope, or you are reading the other node |
