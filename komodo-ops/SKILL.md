---
name: komodo-ops
description: Administer a Komodo (komo.do) Docker orchestration server through the pi-komodo extension's in-process `komodo_*` tools. Use to check or load a session key (`komodo_auth`, `komodo_whoami`), read servers, swarms, stacks, deployments, builds, repos, procedures, actions, resource syncs, builders, alerters, variables, tags, containers, images, networks and volumes; create, update, copy, rename and delete resources; run and poll executions such as deploy, build, sync, start/stop/destroy and Docker prune; read container/stack/deployment logs; export resources as sync TOML; and reach any of the 334 Core operations through `komodo_help` + `komodo_raw`. Trigger whenever the user mentions Komodo, komo.do, Komodo Core or Periphery, or asks to deploy or manage containers across servers through Komodo — even without saying "Komodo".
license: MIT
compatibility: pi with the pi-komodo extension loaded and a Komodo session key (loaded with `/komodo`, or auto-loaded from the `komodo` entry in pi's auth.json). Requires network access to Komodo Core. No Komodo CLI, Docker socket, or database access.
metadata:
  version: "2.0"
  spec: Agent Skills 1.0
  transport: in-process
  docs: https://komo.do
  api-reference: <core-host>/docs
---

# Komodo Operations

Administer a Komodo **Core** instance — a Docker build/deploy orchestrator driving any
number of **Periphery**-connected servers — through the **pi-komodo** extension. Everything
the Komodo UI does is reachable: reads, resource CRUD, executions, logs, users,
permissions, and Core maintenance.

The extension is a **native pi extension**: tools run in-process, with no transport, no
subprocess, and no HTTP client to write. Two layers sit on top of the same 334-operation
Core surface:

| Layer | What it is |
|-------|-----------|
| **Typed tools** (`komodo_stack_action`, `komodo_container_logs`, …) | 91 ergonomic tools for the common path; `_action` tools poll the `Update` to completion for you |
| **`komodo_help` + `komodo_raw`** | the escape hatch: browse the full surface, then call any operation by name |

Everything in this skill describes how to drive those two layers. Raw HTTP is a fallback
for non-pi clients and wire-level debugging ([`references/http-contract.md`](references/http-contract.md)).

## How to use this skill

1. **Check the key first.** `komodo_auth` (and `komodo_health_check`). A keyless session
   cannot call anything — see *Session key* below.
2. **Read the matching pattern** from the Quick Reference table.
3. **Call a typed tool.** Most work needs no more than that.
4. **Drop to `komodo_help` → `komodo_raw`** for anything without a typed tool — the `admin`
   namespace (44 ops: users, permissions, providers), swarm configs/secrets, terminals,
   schedules, batch variants, and Core maintenance.
5. **Read the local conventions** before editing or deploying a stack — see *Instance
   context* below.
6. **Never** run a destructive execution without an explicit user decision. See Safety rules.

## Quick Reference

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| The extension itself: credential wiring, settings, exposure, gating, scrubbing | [`patterns/use-the-extension.md`](patterns/use-the-extension.md) | Configuration and surface policy |
| Session keys, `/komodo`, identity, permissions, minting keys | [`patterns/authenticate.md`](patterns/authenticate.md) | Auth model + 401/403 |
| Listing/reading resources, state, stats, logs, summaries | [`patterns/read-inspect.md`](patterns/read-inspect.md) | Read tools + query semantics |
| Create/update/delete/copy/rename, variables, tags | [`patterns/manage-resources.md`](patterns/manage-resources.md) | Write tools + partial merge |
| Deploy, restart, stop, destroy, build, sync, prune | [`patterns/run-executions.md`](patterns/run-executions.md) | `_action` tools + recreate-not-restart |
| Running a shell on a server/container, reading logs | [`patterns/terminals-and-logs.md`](patterns/terminals-and-logs.md) | Log tools; why shells are SSH, not Komodo |
| Users, service users, groups, permissions, onboarding keys | [`patterns/users-and-permissions.md`](patterns/users-and-permissions.md) | Admin surface (raw) |
| Declarative TOML resources, git sync, managed mode | [`patterns/resource-sync-toml.md`](patterns/resource-sync-toml.md) | Sync + TOML export |
| Reaching an operation that has no typed tool | [`patterns/raw-operations.md`](patterns/raw-operations.md) | `komodo_help` + `komodo_raw` |
| Exact wire format, headers, errors, paging | [`references/http-contract.md`](references/http-contract.md) | Raw HTTP fallback |
| Full request-name index | [`references/endpoint-catalog.md`](references/endpoint-catalog.md) | Offline catalog (prefer `komodo_help`) |
| Query/target/Update/partial-config field meanings | [`references/schemas-and-queries.md`](references/schemas-and-queries.md) | Field semantics |
| Core topology, backups, key rotation, what the API cannot do | [`references/core-operations.md`](references/core-operations.md) | Capability boundaries |
| Instance specifics (conventions, topology) | [`references/kb-hook.md`](references/kb-hook.md) | Local note addresses |

## Session key (the gate)

The extension holds **no ambient credential**. A session starts keyless; the *operator*
loads a key, never the model:

| Command | Effect |
|---------|--------|
| `/komodo status` | show source, identity, fingerprint, permissions |
| `/komodo load ops\|srv\|inf` | masked prompt; the pasted key lives **in memory for the session only** |
| `/komodo clear` | drop the session key |

- **Tiers are labels, not authority.** The real limit is whatever Komodo grants the
  account behind the key. The tiers mirror the vault tiers (`ops` / `srv` / `inf`).
- **`autoLoad`** — `settings.json` → `komodo.autoLoad: "ops"` loads the ambient key from
  pi's `auth.json` at session start with no prompt. Verify with `komodo_auth`.
- **The agent has no load or clear path** (deliberate: it cannot escalate, and cannot
  strand itself). If the key is missing, say so and ask the operator to run `/komodo`.
- `komodo_auth` is read-only status. `komodo_whoami` reports the effective identity and
  permission summary from Komodo. `komodo_health_check` works with **no key** and reports
  Core + extension versions.

## Tool surface

Typed tools, by domain (`_list`/`_info` read, `_apply`/`_delete` write, `_action` executes):

| Domain | Tools |
|--------|-------|
| Servers | `komodo_server_list` · `_info` · `_stats` · `_action` · `_apply` · `_delete` |
| Containers | `komodo_container_list` · `_inspect` · `_logs` · `_search_logs` · `_action` |
| Docker objects | `komodo_docker_image_list` · `_inspect` · `_history` · `komodo_docker_network_list` · `_inspect` · `komodo_docker_volume_list` · `_inspect` |
| Stacks | `komodo_stack_list` · `_info` · `_action` · `_apply` · `_delete` |
| Deployments | `komodo_deployment_list` · `_info` · `_action` · `_apply` · `_delete` |
| Swarms | `komodo_swarm_list` · `_info` · `_apply` · `_delete` · `_action` · `komodo_swarm_nodes_list` · `komodo_swarm_services_list` |
| Builds / builders / repos | `komodo_build_list` · `_info` · `_action` · `_logs` · `_apply` · `_delete`; `komodo_builder_*` (incl. `_copy` · `_rename`); `komodo_repo_*` |
| Procedures / actions / syncs | `komodo_procedure_*`; `komodo_action_*`; `komodo_resource_sync_*` (all `_list`/`_info`/`_action`/`_apply`/`_delete`) |
| Alerters / tags / variables | `komodo_alerter_*`; `komodo_tag_*`; `komodo_variable_*` (`_list`/`_info`/`_apply`/`_delete`) |
| API keys | `komodo_user_list_api_keys` · `komodo_user_create_api_key` · `komodo_user_delete_api_key` |
| Updates | `komodo_update_list` · `komodo_update_info` |
| TOML export | `komodo_toml_export_all` · `komodo_toml_export_resources` |
| Identity / discovery | `komodo_auth` · `komodo_whoami` · `komodo_health_check` · `komodo_help` · `komodo_raw` |

**Raw-only areas** (no typed tool — use `komodo_help` → `komodo_raw`): `admin` (44 ops:
users, service users, groups, permissions, admin flags, onboarding keys, git/image
providers, secrets, server keys), `swarm` configs/secrets, `terminals` (5), `schedules`
(1), plus `alerters` test/send/close, `copy`/`rename` of most resource types, `Batch*`
variants, Core maintenance (`BackupCoreDatabase`, `RotateCoreKeys`, `GlobalAutoUpdate`),
and `system` reads (`GetCoreInfo`, `GetVersion`).

`komodo_exec` (arbitrary shell on a host) exists in the extension but is **excluded in
this deployment** — reach a host over SSH instead, see
[`patterns/terminals-and-logs.md`](patterns/terminals-and-logs.md).

## Safety rules (read before destructive work)

- **The confirmation gate is OFF in this deployment** (`komodo.confirmDestructive: false`
  in `settings.json`), so nothing prompts and nothing fails closed. The discipline in this
  section *is* the guardrail: confirm intent with the user before **destroy / prune /
  delete / stop** on anything shared, on `lax`/`phx`, or that a service depends on.
- **Never `RestartStack` a stack whose services share a Tailscale sidecar namespace**
  (`network_mode: service:ts`). The sidecar returns but the companions do **not** rejoin
  its netns and the stack goes dark on the tailnet — while every container still reports
  healthy. Recreate instead. This is why `komodo_stack_action action="restart"` is
  **refused** by the tool: call `action="destroy"` then `action="deploy"`.
- **Never restart the stack that carries your own route — `litellm`.** It is the gateway
  this agent's own `litellm/*` model calls travel through; a restart can leave it in a
  state a following redeploy does not cleanly recover, and it severs inference mid-turn. A
  plain **redeploy** is fine. Plan with the user, then verify the gateway answers.
- **To apply a config or mount change, recreate — do not stop/restart.** Stop/start/restart
  cycle the *existing* containers; a changed bind-mounted file is never re-read, so a config
  edit silently does nothing. Use `destroy` → `deploy` (named volumes persist).
- `PruneSystem` removes volumes; `destroy`/`_delete` remove containers or resources. Treat
  all three as high blast radius, and never batch a wildcard pattern you have not first
  enumerated with a `_list` call.
- **Database restore/prune/copy are not in the API** — only backup
  (`BackupCoreDatabase`). Never claim a restore via the API; that is a CLI-against-MongoDB
  operation. See [`references/core-operations.md`](references/core-operations.md).
- Prefer read-before-write: fetch with `_info`, compute the partial update, then `_apply`,
  so concurrent editors are not clobbered.
- Treat `K_…` / `S_…` keys and any returned credential as sensitive: never echo them into
  logs or commits. The extension also scrubs secret-shaped output at the tool boundary.

## Common gotchas

- **`_action` is long-running and already polled.** Typed action tools poll
  1 s / max 30 min and return the *finished* `Update` — you do not poll `GetUpdate`
  yourself. On `komodo_raw` you do (poll `GetUpdate` until `status == "Complete"`).
- **`restart` is refused for stacks** and only there; deployments still accept it. The
  refusal is intentional — see the sidecar rule above.
- **`limit: 0` means unlimited.** Otherwise paging defaults to Core's
  `default_pagination_limit` (default 30) and `page` is 0-based.
- **`_apply` is a partial merge.** Unset config fields are preserved, so send only what you
  mean to change — there is no read-modify-write race protection.
- **Names or ids are accepted** for most `id`/`name` fields, but query specifics such as
  `server_ids`/`swarm_ids` accept **ids only**.
- **Check the version.** This deployment runs Core **2.3.3** (extension
  `v1.5.0-pi.1`). The catalog targets 2.3.x; on **< 2.3.0** container endpoints use the old
  `Docker*` names.
- **Compose stacks come in three kinds** (repo-backed, files-on-host, inline) and they are
  edited differently — see the local conventions below before touching one.

## Instance context (local conventions)

Credentials come only from pi's config; topology and most state are derivable from the live
API. What is **not** derivable — how *this* homelab expects stacks to be built, injected,
and torn down — lives in a local Markdown knowledge base. Read the addressed note rather
than browsing the vault; the notes are canonical and this skill only routes to them.

| Subject | Address |
|---------|---------|
| Stack operations: kinds, editing, secrets injection, lifecycle, verification | `14.13` |
| Secrets injection via 1Password Connect | `14.17` |
| Tailscale sidecar wiring and traps | `14.12` |
| Homelab topology (hosts, roles, Komodo Core) | `14.11` |
| Homelab networking (subnets, DNS, VPN) | `14.12` |

```bash
KA="${KB_ROOT:-$HOME/notes/main}"; find "$KA" -iname '14.13*'   # then read the matching note
```

**Before editing or deploying a stack, resolve `14.13` and read it.** Resolution procedure,
etiquette, and secret policy: [`references/kb-hook.md`](references/kb-hook.md). Never copy
note content into this skill — keep one canonical source. If the address does not resolve,
continue with live API discovery and say so.
