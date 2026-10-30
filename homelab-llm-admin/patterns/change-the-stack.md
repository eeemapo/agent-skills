# Change the stack (compose, env, image, mounts)

Layer 3. Only when the **container** is wrong — a missing mount, a missing env
var, a new image, a new service. Never for a model entry: those hot-reload.

## When it is a stack change

| Want | Layer |
|---|---|
| add/remove/retune a model | 1 (llama-swap YAML) |
| expose a model at `ai.` | 2 (LiteLLM YAML) |
| new GPU reservation, mount, port, image digest | **3** |
| new secret / env var | **3** |
| change LiteLLM's *container* flags (`--reload`, etc.) | **3** |

## The flow

    cd ~/repos/komodo            # trimatrix/komodo, branch main
    $EDITOR <stack>/compose.yaml
    git commit -am "<stack>: <what and why>"
    git push origin main

Then deploy through Komodo (tools `komodo_stack_action` with `action: deploy`,
or the UI). Komodo pulls the repo and runs `docker compose up -d` with the
stack's `op run` wrapper, so secrets resolve at deploy time.

**Order matters:** commit and push *before* deploy. Komodo deploys the git
state, not your working tree; a deploy with uncommitted edits silently ships the
previous commit.

## What a deploy restarts

`docker compose up -d` recreates only the services whose definition changed.
A config-only edit to a bind-mounted file (`config/litellm/config.yaml`,
`/opt/ai/config/llama-swap/config.yaml`) does **not** need a deploy at all —
those files are host-owned precisely so they can be edited live.

`config_files` entries in the Komodo stack (`requires: Restart` / `Redeploy`)
are the exception: Komodo compares tracked-file hashes and will restart the
service on the next deploy. That is why the LiteLLM config was moved out of the
repo — a YAML tweak must not cost a restart.

## Selecting which files Komodo tracks

`komodo_stack_apply` with `config.config_files` changes the tracked set, e.g.
drop the LiteLLM config and keep only `ts/ts-serve.json`:

```json
{"config_files": [{"path": "ts/ts-serve.json", "requires": "Restart"}]}
```

This needs **Write** permission on the stack. If it is refused, ask the user —
a permission refusal is not a syntax problem, and retrying will not fix it.

## Rules

- **Never** hand-edit files inside a container or under
  `/etc/komodo/repos/Komodo/…`; those are deploy artifacts and get overwritten.
- **Never** `docker compose up` on a node by hand for a durable change — use the
  Komodo deploy so the repo and the running state stay the same thing.
- Pin images by digest for anything a model depends on; `:latest` is how a
  working stack becomes a mystery.
- A stack deploy can restart a service that had nothing to do with your change
  (dependency health, `--remove-orphans`). Check the deploy output, not just
  `Success`.
- After a deploy, re-verify at the edge (`https://ai.armadillo-hops.ts.net/v1/models`)
  — a healthy container is not a working route.
