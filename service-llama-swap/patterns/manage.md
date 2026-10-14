# Managing models (unload)

Unloading is the only write this contract performs. It is **reversible**: the
next request for that model reloads it (cold start).

    scripts/llama-swap.sh unload <model> --yes    # one model
    scripts/llama-swap.sh unload-all --yes        # everything

Without `--yes` the script refuses and exits 3.

## When to unload

- A GPU is over-committed and a worker is failing to allocate memory.
- You need to swap in a large model on a single-GPU host.
- A model is stuck in a non-`ready` state.

## Guidance

- **Ask first.** `--yes` is an explicit approval token.
- **Prefer the narrowest action**: `unload <model>` over `unload-all`.
- **Verify afterwards** with `running` — the model should be gone.
- Unloading does not stop the swap server or its backends; it only evicts the
  model from memory.

## What NOT to do here

llama-swap's *containers* are defined by llama-swap itself, not by the Docker
orchestrator. To change what a model runs, edit the llama-swap configuration —
do not manage those containers directly.
