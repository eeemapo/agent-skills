# Raw Operations (`komodo_help` + `komodo_raw`)

**Use when** the operation you need has no typed tool — admin, swarm configs, terminals,
schedules, batch variants, Core maintenance, or anything the typed surface does not cover.

The typed tools are a convenience layer over one surface. `komodo_help` reads that surface;
`komodo_raw` calls into it by name. Between them, **all 334 Core operations** are reachable.

## Browse, then call

```
komodo_help                          # namespaces and their operation counts
komodo_help { ns: "stacks" }         # list the operations in one namespace
komodo_help { op: "DeployStack" }    # describe one operation
komodo_raw  { op: "DeployStack", args: { stack: "my-stack" } }
```

- `op` is the **request struct name** (`ListStacks`, `UpdateStack`, `DeployStack`,
  `CreateApiKey`, …).
- `args` is the operation's **params object** — what the API calls `params`. Omit it for
  operations that take none.
- An unknown `op` fails with the message *"Unknown Komodo operation '…'. Browse with
  komodo_help"* — never invent a name; look it up.

## The surface

| Namespace | Ops | Typical use |
|---|---|---|
| `admin` | 44 | users, service users, groups, permissions, onboarding keys, git/image providers, secrets, server keys |
| `servers` | 40 | servers, their containers, Docker objects, server-level maintenance |
| `stacks` | 37 | compose stacks and their executions |
| `swarms` | 36 | swarm clusters, nodes, services, configs, secrets |
| `deployments` | 30 | single-container definitions and executions |
| `builds` | 18 | image builds, build versions, builders-as-resources |
| `repos` | 18 | git repos tracked by Core |
| `containers` | 15 | container lifecycle and inspection |
| `alerters` | 14 | notification sinks, test/send/close alerts |
| `syncs` | 14 | ResourceSync / TOML |
| `actions` | 13 | scheduled TypeScript actions |
| `procedures` | 13 | multi-stage workflows |
| `system` | 12 | Core info, version, maintenance |
| `builders` | 9 | build compute targets (Url / Server / Aws) |
| `variables` | 7 | global variables (incl. secrets) |
| `tags` | 6 | resource tags |
| `terminals` | 5 | terminal sessions (see [`terminals-and-logs.md`](terminals-and-logs.md)) |
| `updates` | 2 | execution history |
| `schedules` | 1 | schedule listing |

Each operation is one of three **kinds**, which decides how it behaves:

| Kind | Meaning |
|------|---------|
| read | returns data |
| write | returns the affected resource (or `NoData`); PATCH-style config merges |
| execute | returns an `Update` you must poll until `status == "Complete"` |

## Risk classes and the gate

Every operation carries a risk class. `komodo_raw` routes `destructive`, `control-plane`,
`terminal`, and `admin` operations through the same confirmation gate as the typed tools.

**In this deployment the gate is off** (`komodo.confirmDestructive: false` in
`settings.json`), so a gated raw call executes with no prompt. That makes *your* discipline
the guardrail: confirm intent with the user before deleting, destroying, pruning, rotating
keys, or changing users/permissions. See [`use-the-extension.md`](use-the-extension.md).

## What is raw-only

These areas have **no** typed tool:

| Area | Examples |
|---|---|
| Admin | `ListUsers`, `CreateServiceUser`, `UpdatePermissionOnTarget`, `CreateOnboardingKey`, `ListSecrets` |
| Permissions checks | `GetPermission`, `ListPermissions` |
| Batch executions | `BatchDeployStack {pattern, tags}`, `BatchDeploy`, `BatchBuildRepo`, … |
| Copy / rename | `CopyStack {name, id}`, `RenameStack {id, name}`, and the same for most types |
| Core maintenance | `BackupCoreDatabase`, `ClearRepoCache`, `GlobalAutoUpdate`, `RotateCoreKeys`, `RotateAllServerKeys` |
| Core/system reads | `GetCoreInfo`, `GetVersion`, `ListSchedules`, `GetContainersSummary` |
| Swarm configs/secrets | `CreateSwarmConfig`, `RotateSwarmSecret`, `RemoveSwarmSecrets` |
| Terminals | `CreateTerminal`, `ListTerminals`, `DeleteTerminal` (+ `POST /terminal/execute`) |
| Alerting | `TestAlerter`, `SendAlert`, `CloseAlert` |
| Resource meta | `UpdateResourceMeta` (description / template / tags on any type) |

A full request-name index, grouped by module, is in
[`../references/endpoint-catalog.md`](../references/endpoint-catalog.md) — useful when you
have no network round-trip to spare; otherwise `komodo_help` is the live, authoritative
source.

## Prefer typed tools when they exist

Typed tools add things raw calls do not:

- **Polling** — `_action` tools wait for the `Update` and report real stage progress; a raw
  execute returns the `Update` and you poll `GetUpdate` yourself.
- **Paging** — `_list` tools page through results for you.
- **Rendering and validation** — clear errors and shaped output instead of a raw JSON blob.
- **Descriptions** — the typed tool's own description documents its parameters and the
  traps specific to it.

So: use `komodo_raw` to **fill a gap**, not as the default path.

## Gotchas

- **`args` is `params`, not the whole envelope** — do not pass `{"type": …, "params": …}`;
  pass just the params object.
- **Operation names are version-sensitive.** This deployment runs Core **2.3.3**; on Core
  < 2.3.0 the container endpoints use the old `Docker*` names. `komodo_help` reflects the
  surface the extension knows.
- **Raw output is unsculpted JSON** (pretty-printed, then scrubbed of secret-shaped values).
  Read it, do not assume a shape.
- **An execute is not a result** — `DeployStack` via raw means *started*. Poll `GetUpdate`
  with the returned id.
- **`limit: 0` means unlimited**; otherwise paging applies. See
  [`read-inspect.md`](read-inspect.md).
