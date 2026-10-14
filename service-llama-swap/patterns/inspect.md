# Inspecting a llama-swap server

## Is it alive?

    scripts/llama-swap.sh health     # prints "OK"
    scripts/llama-swap.sh version    # {"version":"v262", ...}

## What models are configured?

    scripts/llama-swap.sh models

One row per configured model:

    <id>\t<context_length>\t<capabilities>

`capabilities` is a comma-separated list (e.g. `vision`, `function_calling`).
This is the catalog the server *can* serve — **not** what is resident.

## What is loaded right now?

    scripts/llama-swap.sh running

    <model>\t<state>

An empty result means nothing is loaded (all idled out or unloaded). llama-swap
loads a model on first request and can evict it by policy, so residency drifts.

## Profiles

    scripts/llama-swap.sh profiles

Shows configured profiles and which one is active, if the server uses them.

## Logs

    scripts/llama-swap.sh logs 100

Tails the server's buffered logs. It is a stream, so a quiet server returns
nothing rather than an error.

## Choosing between instances

If more than one llama-swap instance exists, the model inventory differs per
host. Confirm the intended `LLAMA_SWAP_URL` first — an unload on the wrong host
evicts someone else's model.
