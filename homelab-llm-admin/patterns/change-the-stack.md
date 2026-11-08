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

## Where a stack lives

Every stack is its own git repo (`homelab/stack-<name>`) deployed as a checkout
on its host:

    /opt/docker/deploy/<name>     compose.yaml · .env · secrets.env.tpl · config/
    /opt/docker/data/<name>       runtime state, bind-mounted

There is **no orchestration plane** — Komodo was decommissioned 2026-11-02 — so
the checkout on the host **is** the deployment, and `git` in it is authoritative.

## The flow

    ssh phx
    cd /opt/docker/deploy/llama-swap-phx
    $EDITOR compose.yaml
    git commit -am "phx: <what and why>"
    git push origin main

    set -a; . /etc/op-connect/connect.env; set +a
    op run --env-file=secrets.env.tpl -- docker compose up -d --remove-orphans --wait

`op run --env-file=secrets.env.tpl` resolves the stack's `op://` references at
launch, so secrets never enter the repo. `den` is the exception: it uses the DMZ
service account in `/etc/op-den/sa.env` (scoped to `HL-DMZ`, not Connect).

Commit **before** the compose run: the checkout is the deploy artifact, and a
re-clone has to reproduce what is running.

## What a compose run restarts

`docker compose up -d` recreates only the services whose definition changed.
A config-only edit to a bind-mounted file
(`config/llama-cpp/config.yaml`, `config/litellm/config.yaml`) does **not** need
one at all — those files hot-reload, which is why they live in the checkout
rather than in the image.

## Anchors

`gitea` and `op-connect` are hand-run: never "deploy" them from anything else,
and never `down -v` either — the volumes are the data.

## Rules

- **Never** hand-edit files inside a container; the host file is the source.
- **Never** re-materialise `/opt/docker/deploy/<stack>` under a running
  container (`rm -rf` + re-clone, rsync into a fresh directory). The bind is
  resolved at container start, so the container keeps the deleted inode:
  hot reload stops silently while the stale in-memory config keeps serving.
  `docker restart <container>` restores it; verify with
  `docker exec … md5sum /llama-config/config.yaml` against the host file.
- Pin images by digest for anything a model depends on; `:latest` is how a
  working stack becomes a mystery.
- A compose run can restart a service that had nothing to do with your change
  (dependency health, `--remove-orphans`). Watch the output, not just `Started`.
- After a stack change, re-verify at the edge
  (`https://ai.armadillo-hops.ts.net/v1/models`) — a healthy container is not a
  working route.
