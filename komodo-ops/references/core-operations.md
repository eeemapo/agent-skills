# Core Operations, Capabilities, and Topology

## Topology

- **Komodo Core** — the server you talk to. It hosts the HTTP API, the UI, the scheduler, and the MongoDB database.
- **Komodo Periphery** — a small agent installed on every managed server. Core sends commands to Periphery over a bi-directional connection; Periphery is stateless and does the actual Docker work.

So an API call like `DeployStack` only tells **Core** what to do; Core then drives Periphery on the target server. The server's `address`/connection state is visible via `GetServer`, `GetServerState`, and `GetPeripheryInformation`.

## What the API covers

| Capability | Via API |
|------------|---------|
| Read everything (resources, state, stats, logs, updates) | Yes (`/read`) |
| Create/update/delete/copy/rename all resources | Yes (`/write`) |
| Execute builds/deploys/stacks/swarms/maintenance | Yes (`/execute`) |
| Terminals (server shell, container exec/attach) | Yes (`/write/CreateTerminal` + `/terminal/execute` + `/ws`) |
| Users, groups, permissions, API/onboarding keys | Yes (`/write`, admin) |
| Declarative TOML resources | Yes (`/read` export, `/write` sync, `/execute/RunSync`) |
| Core database **backup** | Yes — `/execute/BackupCoreDatabase` (admin) |

## What the API does **not** cover

- **Database restore, prune, and copy.** There is no API endpoint for these. They are performed by the Komodo CLI directly against MongoDB, from wherever it can reach the database. Do not promise a restore via the API.
- **Core/Periphery config-file editing.** `core.config.toml` / `periphery.config.toml` are operator-managed on disk and require a process restart.
- **PKI/private-key file utilities.** Local tooling only.
- **Creating the very first admin/API key from nothing.** An existing credential (issued via the UI, or a `/auth` JWT login) is required before an API key can be minted.

## Core maintenance executions (admin)

```jsonc
POST /execute { "type": "BackupCoreDatabase", "params": {} }                        // writes a timestamped dump to Core's /backups
POST /execute { "type": "ClearRepoCache",     "params": {} }                        // drop Core's cached repos
POST /execute { "type": "GlobalAutoUpdate",  "params": {"skip_auto_update": false} } // poll all auto-update resources
POST /execute { "type": "RotateAllServerKeys","params": {} }
POST /execute { "type": "RotateCoreKeys",    "params": {"force": false} }
```

Per-server key rotation is also available as `/write/RotateServerKeys` `{server}`.

## Core info and feature flags

`GetCoreInfo` reports operational settings you may need to respect:
- `title`, `timezone`, `monitoring_interval`
- `transparent_mode` — all users get read access to all resources
- `ui_write_disabled`, `disable_non_admin_create`, `disable_confirm_dialog`
- `disable_websocket_reconnect`, `enable_fancy_toml`
- `default_pagination_limit` (used when `limit` is omitted)
- `public_key`

`ListSecrets` lists configured secret **keys** (not values) in Core config, optionally expanded for a Server/Builder target.

## Realtime: websocket and webhooks

- `GET /ws` streams live updates; useful for long builds/deploys instead of polling. Types in `/client/types.d.ts`.
- Core exposes git webhook receivers at `/listener/github/*` and `/listener/gitlab/*`; a ResourceSync or Build with `webhook_enabled` can be triggered by pushes. `GetCoreInfo.webhook_base_url` is the base to configure in the git provider.

## Versioning and clients

- `GET /version` returns the Core package version (unauthenticated) — quick liveness check.
- **Check the version before trusting the catalog.** This skill targets Core **2.3.x**; on **< 2.3.0** the container/Docker endpoints use old `Docker*` names (see the compatibility table in [`endpoint-catalog.md`](endpoint-catalog.md)). Where possible, run Core `>= 2.3.0` so the documented names apply directly.
- `GET /docs` serves the full interactive OpenAPI reference (schema source of truth).
- `GET /client/{lib,types,responses,terminal}.{js,d.ts}` serves generated TypeScript client and types; a Rust client (`komodo_client`) exists on crates.io.

## Adding a server

1. `/write/CreateOnboardingKey` (admin) → returns `{private_key, created}`.
2. Install Periphery on the target with `--core-address` and the onboarding key.
3. Confirm with `/read/ListServers` that the server reaches state `Ok` (or `GetServer`).

If `copy_server` was set at key creation, the new server inherits that server's config; `create_builder` also provisions a builder.

## Backups in practice

- Trigger `/execute/BackupCoreDatabase`; Core writes a timestamped folder of gzip dumps under `/backups` (mount a host path there). Retention is controlled by Core config (`max_backups`).
- Default new installs also schedule a `Backup Core Database` Procedure daily.
- Restoring is a CLI/Mongo operation, not API — coordinate with the operator.

## Deployment reference (in the Komodo repo)

- Setup: `docsite/docs/setup/index.mdx`, `docsite/docs/setup/connect-servers.mdx`, `docsite/docs/setup/advanced.mdx`, `docsite/docs/setup/backup.md`
- Config: `docsite/docs/configuration/permissioning.md`, `variables.md`, `providers.md`
- Automation: `docsite/docs/automate/schedules.md`, `procedures.md`, `sync-resources.md`, `webhooks.md`
