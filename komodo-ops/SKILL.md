---
name: komodo-ops
description: Administer a Komodo (komo.do) Docker orchestration server with the pi-komodo extension's `komodo_*` tools (JSON HTTP API underneath). Use this skill to authenticate to Komodo Core with API keys, discover and read servers, swarms, stacks, deployments, builds, repos, procedures, actions, resource syncs, builders, alerters, users and containers; create, update, copy, rename and delete resources; trigger executions such as deploy, restart, stop, prune, build and sync and poll their Update results; query container/stack/deployment logs; manage terminal sessions; administer users, user groups, permissions, tags, providers, variables and API/onboarding keys; and trigger Core database backups and key rotation. Trigger whenever the user mentions Komodo, komo.do, Komodo Core or Periphery, or asks to deploy or manage containers across servers through Komodo — even if they do not say "Komodo" explicitly.
license: MIT
compatibility: Requires network access to a running Komodo Core instance and an API key/secret (or a user JWT). No local CLI, Docker socket, or database access is required.
metadata:
  transport: http-json
  docs: https://komo.do
  api-reference: <core-host>/docs
---

# Komodo API Operations

Administer a Komodo **Core** instance — a Docker build/deploy orchestrator managing any number of **Periphery**-connected servers — entirely over its JSON HTTP API. Everything the Komodo UI does is available here: reads, resource CRUD, executions, logs, terminals, users, permissions, and Core maintenance.

## How to use this skill

1. Read the matching pattern from the Quick Reference table below.
2. Call the `komodo_*` tools — see [`patterns/use-the-extension.md`](patterns/use-the-extension.md); if credentials don't resolve, see `patterns/authenticate.md`.
3. For the exact wire format and error shape, load `references/http-contract.md`.
4. For the endpoint you need, load `references/endpoint-catalog.md`.
5. For field-level request/response shapes, Core serves interactive OpenAPI docs at `GET <core-host>/docs` (and the generated TypeScript types at `/client/types.d.ts`).
6. Never trigger a destructive execution or permission change without an explicit user decision; see Safety rules.

## Quick Reference

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| Getting/using an API key, headers, permission model | [`patterns/authenticate.md`](patterns/authenticate.md) | Auth + 401/403 behaviour |
| Listing / reading resources, state, logs, stats | [`patterns/read-inspect.md`](patterns/read-inspect.md) | Read endpoints + filtering |
| Create/update/delete/copy/rename resources, vars, tags | [`patterns/manage-resources.md`](patterns/manage-resources.md) | Write endpoints + partial merge |
| Deploying, restarting, stopping, pruning, builds, syncs | [`patterns/run-executions.md`](patterns/run-executions.md) | Execute endpoint + Update polling |
| Terminal sessions, container/stack logs | [`patterns/terminals-and-logs.md`](patterns/terminals-and-logs.md) | Streaming terminal + logs |
| Users, service users, groups, permissions, onboarding keys | [`patterns/users-and-permissions.md`](patterns/users-and-permissions.md) | Admin endpoints |
| Declarative TOML resources, git sync, managed mode | [`patterns/resource-sync-toml.md`](patterns/resource-sync-toml.md) | Export/commit/sync |
| The exact HTTP contract, headers, errors, paging | [`references/http-contract.md`](references/http-contract.md) | Wire format |
| Full list of read / write / execute / auth endpoints | [`references/endpoint-catalog.md`](references/endpoint-catalog.md) | Endpoint index |
| Shared schemas: queries, targets, Update, partial config | [`references/schemas-and-queries.md`](references/schemas-and-queries.md) | Field meanings |
| Core maintenance, backups, key rotation, deployment model | [`references/core-operations.md`](references/core-operations.md) | What the API can/cannot do |
| Instance-specifics from the knowledge base | [`references/kb-hook.md`](references/kb-hook.md) | Local note addresses |
| Calling Komodo from an agent (the supported path) | [`patterns/use-the-extension.md`](patterns/use-the-extension.md) | `komodo_*` tools + credential wiring |
| Raw HTTP (debugging / non-pi clients) | [`references/http-contract.md`](references/http-contract.md) | Wire format |

## The API in one paragraph

Every call is `POST https://<core-host>/<module>` with JSON body `{"type": "<RequestName>", "params": { ... }}` and headers `Content-Type: application/json`, `X-Api-Key: K-...`, `X-Api-Secret: S-...`. Modules are `/auth`, `/read`, `/write`, `/execute`, and `/terminal/execute`. Reads return data; writes return the affected resource; **executes return an `Update`** whose `id` you poll with `/read/GetUpdate` until `status: "Complete"`. Errors are `{ "error": "...", "trace": [...] }` with a non-2xx status.

## Patterns by workflow

### Access
- **[`patterns/authenticate.md`](patterns/authenticate.md)** — API keys, service users, JWT login, permission checks.

### Observe
- **[`patterns/read-inspect.md`](patterns/read-inspect.md)** — list resources with queries, summaries, live state, container/stack logs, server stats.

### Change configuration
- **[`patterns/manage-resources.md`](patterns/manage-resources.md)** — CreateX / UpdateX / DeleteX / CopyX / RenameX, `UpdateResourceMeta`, variables, tags, providers.
- **[`patterns/resource-sync-toml.md`](patterns/resource-sync-toml.md)** — export resources to TOML, drive ResourceSyncs, commit managed changes.
- **[`patterns/users-and-permissions.md`](patterns/users-and-permissions.md)** — users, service users, user groups, permissions, onboarding/API keys.

### Act on infrastructure
- **[`patterns/run-executions.md`](patterns/run-executions.md)** — deploy/restart/stop/destroy/prune/build/sync, batch executions, polling results.
- **[`patterns/terminals-and-logs.md`](patterns/terminals-and-logs.md)** — run shell commands on servers/containers, read logs.

## Instance context (optional)

Credentials come only from the environment; topology is derived from the live API. For non-derivable specifics (ownership, environment names, maintenance windows, conventions), this skill can hook to a local knowledge base:

- Base path: `$KB_ROOT` (default `~/notes/main`).
- Notes use a Johnny Decimal address. For this deployment, homelab topology is **`14.11`** and networking is **`14.12`**: resolve with `find "${KB_ROOT:-$HOME/notes/main}" -iname '14.11*'`, then read the matching note.
- Endpoint/keys come from pi's `auth.json` `komodo` entry (see [`patterns/use-the-extension.md`](patterns/use-the-extension.md)); notes record env var **names**, never secret values.
- If the KB is absent or an address is missing, proceed with live API discovery — never block on it.
- Never write secrets, keys, or full credential values into the KB.

See [`references/kb-hook.md`](references/kb-hook.md) for the scheme and note etiquette.

## Tools (pi-komodo extension)

Administer Komodo through the **pi-komodo** extension's in-process `komodo_*` tools — no HTTP client, no git-synced scripts. Full surface, credential wiring, and examples: [`patterns/use-the-extension.md`](patterns/use-the-extension.md).

- **Credentials:** pi `auth.json` `komodo` entry (`type: api_key`, with `key`/`apiSecret`/`url` values that may be leading-`!command` refs, e.g. to the 1Password Connect helper) → env `KOMODO_*` → `KOMODO_*_FILE` → config file. `auth.json` wins; **restart pi** after rotating a key.
- **Naming:** `komodo_<resource>_<verb>` — reads `_list`/`_info`, writes `_apply`/`_delete`, actions `_action` (returns the finished `Update`). Create service users/keys with `komodo_user_*` (e.g. `komodo_user_create_api_key`).
- **Guardrails:** destructive tools confirm via pi's dialog and fail closed headless unless `MCP_CONFIRM_FALLBACK=allow`; `KOMODO_PI_EXPOSURE` / `MCP_TOOLS_*` prune the surface (exclude `komodo_exec` unless intended).
- **Verify:** `komodo_health_check` → `configured: true, healthy: true`.

## Safety rules (read before destructive work)

- Confirm intent before **destroy / prune / delete / stop** requests. They are irreversible on the target host.
- Executions are asynchronous and can affect many resources at once (batch executions accept wildcard/regex patterns). Resolve the exact target set first with `/read/List*` and `-f`-style queries, then execute.
- `PruneSystem` removes volumes; `DestroyStack`/`DestroyDeployment` remove containers. Treat both as high blast-radius.
- Database **restore/prune/copy are not in the API** — only backup (`/execute/BackupCoreDatabase`). Do not claim to restore the Core database via the API; that requires the CLI against MongoDB. See `references/core-operations.md`.
- Admin-only endpoints (`**Admin only**` in `references/endpoint-catalog.md`) require an admin user's key; `CreateLocalUser`/`DeleteUser`/permissions and service-user management will 403 otherwise.
- Prefer read-before-write: fetch the resource, compute the partial update, then `UpdateX`, so concurrent editors are not clobbered.
- Treat `K-...` / `S-...` secrets and any returned credentials as sensitive: never echo them into shared logs or commits.

## Common gotchas

- **`params` only, or `type`+`params`?** Both work: `POST /read` with `{"type":"ListStacks","params":{...}}`, or `POST /read/ListStacks` with just the params object. The generated TS/Rust clients use the first form.
- **`limit: 0` means unlimited.** Default page size is Core's `default_pagination_limit` (default 30); `page` is 0-based. Summary endpoints (`Get*Summary`) return `{total, running, stopped, down, unhealthy, unknown}`.
- **Config updates merge.** `UpdateX` takes a *partial* config; unset fields are preserved. There is no read-modify-write race safety, so send only the fields you intend to change.
- **Names or ids are accepted** for most `id`/`name` fields (serde aliases), but query specifics like `server_ids`/`swarm_ids` accept **ids only**.
- **`UpdateResourceMeta`** is the shared way to set description/template/tags on any resource type.
- **Executions return `Update`, not the finished result.** Poll `/read/GetUpdate` until `status == "Complete"`, then check `success` and `logs`.
- **Terminal execute returns a raw byte stream**, not JSON. Create the session first (`/write/CreateTerminal`) when you need a stable named session.
- Use `GET /user` to confirm which identity a key maps to, and `/read/GetPermission` before operating on a resource you may only partially control.
- **Check `GetVersion` first.** The catalog targets Core 2.3.x; on **< 2.3.0** container endpoints use old `Docker*` names (see [`references/endpoint-catalog.md`](references/endpoint-catalog.md)).
