# Shared Schemas and Queries

Field-level truth is always `GET <core-host>/docs`; this page covers the structures you will reuse across most calls.

## List request (generic)

```jsonc
{
  "query": { ... },        // resource-specific structured filter
  "page": 0,               // 0-based
  "limit": 30,              // 0 = unlimited; default = Core default_pagination_limit
  "sort_by": "Name",       // enum per resource
  "sort_desc": false
}
```

Some list endpoints (`ListAllContainers`, `ListAllStackServices`, `ListAll*`) use flat filters (`servers`, `tags`, `terms`, `state`, `page`, `limit`, `sort_by`, `sort_desc`) instead of a `query` object.

## `ResourceQuery<T>`

Backing most `ListX` endpoints:

| Field | Meaning |
|-------|---------|
| `terms: [..]` | name must contain **all** terms (case-insensitive substring) |
| `names: [..]` | exact resource names, or ids (`_id`) |
| `tags: [..]` | tag **ids or names** |
| `tag_behavior` | `All` (default) or `Any` |
| `templates` | `Include` (default), `Exclude`, `Only` |
| `specific` | resource-specific block, e.g. `StackQuerySpecifics` |

Example specifics (`StackQuerySpecifics`): `server_ids` (ids only), `swarm_ids` (ids only), `linked_repos`, `repos`, `update_available`, `states`. Other resource types have analogous specifics (`ServerQuery`, `DeploymentQuery`, ...).

## Resource envelopes

**List item** (`ResourceListItem<Info>`):
```jsonc
{ "id": "...", "type": "Stack", "name": "my-stack",
  "template": false, "tags": ["<tag-id>"], "info": { /* state */ } }
```

**Full resource** (`GetX` / `ListFullX`):
```jsonc
{ "id": "...", "name": "my-stack", "template": false,
  "tags": ["<tag-id>"], "description": "...",
  "config": { ... }, "info": { ... } }
```

Unwrap the wrapped `Read`/`Write` response envelope is not needed — the value is the response body directly.

## Targets

**`ResourceTarget`** — identifies any resource:
```jsonc
{ "type": "Stack", "id": "my-stack" }
```
Variants: `Server`, `Swarm`, `Stack`, `Deployment`, `Build`, `Repo`, `Procedure`, `Action`, `Alerter`, `Builder`, `ResourceSync` (and user tags).

**`UserTarget`**: `{"type":"User","id":"..."}` or `{"type":"UserGroup","id":"..."}`.

**`TerminalTarget`**: `{"type":"Server","params":{...}}`, `{"type":"Container","params":{server,container}}`, `{"type":"Stack","params":{stack,service?}}`, `{"type":"Deployment","params":{deployment}}`.

## Permissions

```jsonc
{ "level": "Write", "specific": ["Terminal", "Logs"] }
```

- `PermissionLevel` (ordered): `None` < `Read` < `Execute` < `Write`.
- `specific`: `Terminal`, `Attach`, `Inspect`, `Logs`, `Processes`.
- Combined grants take the max level and the union of specifics.

## Updates and logs

**`Update`** (returned by every execution):
```jsonc
{ "_id": {"$oid": "..."}, "operation": "DeployStack", "status": "InProgress",
  "success": false, "operator": "<user-id | Procedure | Github | Auto Redeploy>",
  "target": {"type":"Stack","id":"my-stack"}, "logs": [ ... ],
  "start_ts": 0, "end_ts": null, "version": {}, "commit_hash": "",
  "other_data": "", "prev_toml": "", "current_toml": "" }
```
- `UpdateStatus`: `Queued` → `InProgress` → `Complete`.
- Poll `GetUpdate` until `Complete`; then trust `success` and `logs`.

**`Log`**: `{ stage, command, stdout, stderr, success, start_ts, end_ts }`.

**`UpdateListItem`** (from `ListUpdates`): slim version with `username`, `operation`, `start_ts`, `success`, `target`, `status`, `version`, `other_data`.

## Partial config merge

`UpdateX` takes a `_PartialXConfig`. Only fields present in the JSON are applied; omitted fields are preserved. Nested partial objects merge. This is how you avoid clobbering concurrent edits — but it is still read-modify-write, so fetch first when the decision depends on current values.

`CreateX` also accepts a partial config to initialize.

## Common resource config fields

Most resources share `name`, `description`, `tags`, and `template`; type-specific config differs (e.g. Stack: `server_id`/`swarm_id`, `repo`, `branch`, `file_contents`, `files_on_host`, `resource_path`, `managed`; Deployment: `server_id`, `image`, `ports`, ...). Always confirm keys from `/docs`.

## ResourceSync diff data

```jsonc
{ "type": "Update", "data": { "proposed": "<toml>", "current": "<toml>" } }
{ "type": "Create", "data": { "name": "...", "proposed": "<toml>" } }
{ "type": "Delete", "data": { "current": "<toml>" } }
```

`ResourceSyncInfo.resource_updates` is `[{target, data}]`; `variable_updates` and `user_group_updates` are `[DiffData]`.

## Enumerations worth memorizing

- `UpdateStatus`: `Queued`, `InProgress`, `Complete`.
- `ResourceSyncState`: `Syncing`, `Pending`, `Ok`, `Failed`, `Unknown`.
- `ContainerTerminalMode`: `exec`, `attach`.
- `TerminalRecreateMode`: `Never`, `Always`, `DifferentCommand`.
- `TemplatesQueryBehavior`: `Include`, `Exclude`, `Only`.
- `TagQueryBehavior`: `All`, `Any`.
- `SearchCombinator`: `And`, `Or`.

Full schemas and every enum: `GET <core-host>/docs`, or the generated TypeScript at `/client/types.d.ts`.
