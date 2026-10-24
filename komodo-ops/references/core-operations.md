# Core Operations, Capabilities, and Boundaries

## Topology

- **Komodo Core** — the server you talk to. Hosts the API, the UI, the scheduler, and the
  MongoDB database.
- **Komodo Periphery** — a small agent on every managed server. Core drives it over a
  bi-directional connection; Periphery is stateless and does the actual Docker work.

So a call like `DeployStack` only tells **Core** what to do; Core then drives Periphery on the
target server. Connection state is visible with `komodo_server_info` / `komodo_server_stats`
(raw: `GetServer`, `GetServerState`, `GetPeripheryInformation`).

## What the surface covers

| Capability | How |
|------------|-----|
| Read everything (resources, state, stats, logs, updates) | typed `_list`/`_info`/`_logs` tools |
| Create/update/delete/copy/rename resources | typed `_apply`/`_delete`; `Copy*`/`Rename*` via `komodo_raw` |
| Builds, deploys, stacks, swarms, maintenance | typed `_action` tools (polled) + `komodo_raw` |
| Users, groups, permissions, API/onboarding keys | `komodo_raw` (admin namespace) |
| Declarative TOML resources | `komodo_resource_sync_*`, `komodo_toml_export_*` |
| Terminals (server shell, container exec/attach) | `komodo_raw` only — and deliberately off the normal path |
| Core database **backup** | `komodo_raw { op: "BackupCoreDatabase" }` (admin) |

## What it does **not** cover

- **Database restore, prune, and copy.** No API operation exists. These are the Komodo CLI
  against MongoDB, run where the database is reachable. Never promise a restore via the API.
- **Core/Periphery config-file editing.** `core.config.toml` / `periphery.config.toml` are
  operator-managed on disk and need a process restart.
- **PKI / private-key file utilities.** Local tooling only.
- **Creating the very first admin/API key from nothing.** An existing credential (issued in
  the UI, or a JWT login) is required before any key can be minted.

## Core maintenance (admin, via `komodo_raw`)

```
komodo_raw { op: "BackupCoreDatabase",  args: {} }                                  # timestamped dump to Core's /backups
komodo_raw { op: "ClearRepoCache",      args: {} }                                  # drop Core's cached repos
komodo_raw { op: "GlobalAutoUpdate",    args: { skip_auto_update: false } }         # poll every auto-update resource
komodo_raw { op: "RotateAllServerKeys", args: {} }
komodo_raw { op: "RotateCoreKeys",      args: { force: false } }
komodo_raw { op: "RotateServerKeys",    args: { server: "prod-01" } }               # per-server (write)
```

`GlobalAutoUpdate` can redeploy many resources at once — scope it or pass `skip_auto_update`.
Key rotation invalidates the credentials Core holds for servers; plan it with the user.

## Core info and feature flags

`komodo_raw { op: "GetCoreInfo" }` reports settings you may need to respect:

- `title`, `timezone`, `monitoring_interval`, `public_key`
- `transparent_mode` — all users get read access to all resources
- `ui_write_disabled`, `disable_non_admin_create`, `disable_confirm_dialog`
- `disable_websocket_reconnect`, `enable_fancy_toml`
- `default_pagination_limit` — used when `limit` is omitted (default 30)
- `webhook_base_url` — the base to configure in a git provider

`ListSecrets` lists configured secret **keys** (not values) in Core config, optionally expanded
for a Server/Builder target. Names only — never try to read the values.

## Realtime: websocket and webhooks

- `GET /ws` streams live updates; useful for long builds/deploys instead of polling. Types in
  `/client/types.d.ts`. The typed `_action` tools already poll, so this matters mainly for
  non-pi clients.
- Core receives git webhooks at `/listener/github/*` and `/listener/gitlab/*`; a ResourceSync
  or Build with `webhook_enabled` can be triggered by a push.

## Versioning and clients

- `komodo_health_check` reports the Core and extension versions; raw: `GET /version`
  (unauthenticated) or `GetVersion`.
- **This deployment runs Core 2.3.3** (extension `v1.5.0-pi.1`). The catalogs here target
  **2.3.x**; on **< 2.3.0** the container/Docker endpoints use the old `Docker*` names (see
  the compatibility table in [`endpoint-catalog.md`](endpoint-catalog.md)).
- `GET <core-host>/docs` serves the interactive OpenAPI reference (the schema source of
  truth); `/client/{lib,types,responses,terminal}.{js,d.ts}` serves generated TypeScript
  clients. A Rust client (`komodo_client`) exists on crates.io.

## Adding a server

```
komodo_raw { op: "CreateOnboardingKey", args: { name: "new-node", expires: 0, tags: ["prod"] } }
# -> { private_key, created }
```

1. Create the onboarding key (admin). Core stores only its public key.
2. Install Periphery on the target with `--core-address` and `--onboarding-key`.
3. Confirm with `komodo_server_list` that the server reaches state `Ok`.

`copy_server` at creation time makes the new server inherit that server's config;
`create_builder` also provisions a builder.

## Backups in practice

- `BackupCoreDatabase` writes a timestamped folder of gzip dumps under Core's `/backups` (mount
  a host path there). Retention is a Core config setting (`max_backups`).
- New installs also schedule a daily `Backup Core Database` Procedure — check with
  `komodo_procedure_list`.
- **Restoring is a CLI/Mongo operation, not an API one.** Coordinate with the operator.

## Deployment reference (in the Komodo repo)

- Setup: `docsite/docs/setup/{index,connect-servers,advanced}.mdx`, `backup.md`
- Config: `docsite/docs/configuration/{permissioning,variables,providers}.md`
- Automation: `docsite/docs/automate/{schedules,procedures,sync-resources,webhooks}.md`
