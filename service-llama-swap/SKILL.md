---
name: service-llama-swap
description: Inspect and control a llama-swap server — list the configured models and their capabilities, see which models are currently loaded, read profiles and logs, and (behind an explicit approval gate) unload one model or all running models. Use when working with a llama-swap (or llama.cpp proxy) instance, when checking what local models are available or resident, when diagnosing a stuck or over-committed GPU, or when a model must be unloaded. Covers the bearer-token auth and the --yes write gate.
license: MIT
compatibility: Client-agnostic. Requires network access to a llama-swap instance and its API key via environment variables. Uses curl and jq.
metadata:
  version: "1.0"
  spec: Agent Skills 1.0
  upstream: llama-swap HTTP API
---

# llama-swap Contract

llama-swap fronts one or more inference backends and hot-swaps models on demand.
Its HTTP API exposes an OpenAI-compatible `/v1` surface plus control endpoints.
Deterministic work lives in [`scripts/llama-swap.sh`](scripts/llama-swap.sh);
the endpoint catalog is in [`references/http-api.md`](references/http-api.md).

## How to use this skill

1. Supply configuration from the environment (see **Configuration**). Resolve the
   key into `LLAMA_SWAP_KEY` **without echoing it**.
2. Run a verb as a program (do **not** `source` it):
   `bash <skill-dir>/scripts/llama-swap.sh <verb> [args]`
   (absolute path — a bare `scripts/` path fails as “not found”, which is a
   **path** problem, not an authentication failure).
3. If a verb fails, read **Gotchas** before changing anything.

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| What models exist / what can they do | [`patterns/inspect.md`](patterns/inspect.md) | Model list shape and capability fields |
| Freeing a GPU / unloading models | [`patterns/manage.md`](patterns/manage.md) | Unload verbs and the `--yes` gate |
| Exact endpoints and params | [`references/http-api.md`](references/http-api.md) | Wire-level catalog |

## Verbs

    scripts/llama-swap.sh --help
    # read (safe)
    scripts/llama-swap.sh health          # liveness
    scripts/llama-swap.sh version         # build/version
    scripts/llama-swap.sh models          # configured models + context + capabilities
    scripts/llama-swap.sh running         # currently loaded models
    scripts/llama-swap.sh profiles        # profiles and the active one
    scripts/llama-swap.sh logs [n]        # tail buffered logs
    # write (require --yes)
    scripts/llama-swap.sh unload <model> --yes
    scripts/llama-swap.sh unload-all --yes

## Configuration

| Variable | Required | Meaning |
|----------|----------|---------|
| `LLAMA_SWAP_URL` | yes | Base URL, e.g. `https://llama-swap.example.invalid` |
| `LLAMA_SWAP_KEY` | yes | API key (sent as `Authorization: Bearer …`) |

`LLAMA_SWAP_URL` is **not** a credential and is **not** a field in the vault item —
take it from the task or the host inventory. Resolve only the key from the vault.

Reads are safe by default. **Unloads refuse to run without `--yes`** — pass it only
once the user has approved.

## Gotchas

- **A model listed by `models` is not loaded.** Configuration ≠ residency. Use
  `running` to see what is actually in memory; `models` is the catalog.
- **Loading is on demand.** Unloading is safe — the next request for that model
  reloads it (at the cost of a cold start). Do not treat unload as data loss.
- **`/v1/models` is lazy.** Some servers only report a model once it has been
  requested at least once; `running` is the reliable residency signal.
- **`/logs` is a stream**, not a file: the script caps it with a timeout and
  `tail`, so a quiet server legitimately returns nothing.
- Multiple instances are common (one per host); confirm which `LLAMA_SWAP_URL`
  you were given before unloading.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | success |
| 1 | configuration or HTTP error |
| 2 | unknown verb |
| 3 | a write verb was called without `--yes` |
