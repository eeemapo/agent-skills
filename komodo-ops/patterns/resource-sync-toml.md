# Declarative Resources (ResourceSync / TOML)

**Use when** you want resources managed as versioned TOML files in git (or on the Core
host), diffed and applied — Komodo's infrastructure-as-code path.

## What a ResourceSync does

A `ResourceSync` points at TOML file(s) declaring resources (`[[server]]`, `[[stack]]`,
`[[deployment]]`, …). Core polls the source, computes a diff against existing resources, and
on **run** creates/updates/deletes to match. It can also own variables and user groups.

```
komodo_resource_sync_list
komodo_resource_sync_info      { resource_sync: "prod-resources" }   # includes pending diffs
komodo_resource_sync_action    { resource_sync: "prod-resources", action: "refresh" }  # preview only
komodo_resource_sync_action    { resource_sync: "prod-resources", action: "run" }      # apply
komodo_resource_sync_apply     { action: "create" | "update", … }
komodo_resource_sync_delete    { resource_sync: "prod-resources" }
```

`refresh` recomputes the pending-changes preview without applying anything; `run` applies it.
**Read `komodo_resource_sync_info` (or `refresh`) before every `run`.**

## Sync config keys

`komodo_resource_sync_apply` (`action="create"` needs `name`; `action="update"` needs the
sync id/name) takes a `config` object:

| Key | Meaning |
|-----|---------|
| `repo` + `branch` + `git_provider` + `git_https` + `git_account` | source git repo (or set `linked_repo` to a Komodo Repo resource) |
| `files_on_host` + `resource_path` | files on the Core host, relative to Core's `sync_directory` |
| `managed` | push UI/API changes back to the file/repo and commit (managed mode) |
| `match_tags` | limit managed exports to resources carrying all these tags |
| `delete` | delete resources not declared in the files |
| `include_resources` / `include_variables` / `include_user_groups` | what the sync owns |
| `webhook_enabled` + `webhook_secret` | allow a git push webhook to trigger the sync |

```
komodo_resource_sync_apply { action: "create", name: "prod-resources", config: {
  repo: "my-org/komodo-resources", branch: "main",
  resource_path: ["prod/"], managed: true, match_tags: ["prod"], delete: false } }
```

## Writing sync files (raw)

```
komodo_raw { op: "WriteSyncFileContents", args: {
  sync: "prod-resources", resource_path: "prod", file_path: "stacks.toml", contents: "…" } }
komodo_raw { op: "RefreshResourceSyncPending", args: { sync: "prod-resources" } }
komodo_raw { op: "CommitSync", args: { sync: "prod-resources" } }     # managed mode: commit the export back
```

**`CommitSync` is a write, not an execute** — the only "run" verb that is. Everything else
(`RunSync`) goes through the execute path, which `komodo_resource_sync_action` handles.

## Reading the diff

`komodo_resource_sync_info` returns the sync resource including:

- `resource_updates: [{target, data: {type, data}}]`, where `DiffData` is
  `Create {name, proposed}`, `Update {proposed, current}`, or `Delete {current}`
- `variable_updates`, `user_group_updates`
- `pending_deploys`, `pending_error`, `pending_hash`, `pending_message`
- `remote_contents` / `remote_errors` for the fetched files

State (`ResourceSyncState`): `Syncing`, `Pending` (diffs waiting), `Ok`, `Failed`, `Unknown`.
A sync sitting in `Pending` is a change that has **not** been applied.

## Export existing resources → TOML

```
komodo_toml_export_all { tags?: "prod" }
komodo_toml_export_resources { targets: "Stack:web, Deployment:api" }
```

Secret values (variable values, server passkeys, alerter webhook URLs) are **redacted**, so an
export is for inspection and diffing, not for verbatim re-apply. Use it to seed a sync file,
then point a ResourceSync at the file. `komodo_stack_info` / `_list` give the same data in
structured form.

## Typical IaC workflow

```
komodo_toml_export_all                                  # 1. look at current state
komodo_resource_sync_apply { action: "create", … }      # 2. declare the sync (once)
komodo_resource_sync_action { …, action: "refresh" }    # 3. recompute diffs
komodo_resource_sync_info { resource_sync: "…" }        # 4. READ the diff — this is the gate
komodo_resource_sync_action { …, action: "run" }        # 5. apply
```

## Safety

- With `delete: true`, resources absent from the files are **deleted**. Read the diff first;
  never run a sync whose pending deletes you have not listed to the user.
- `managed` mode writes and commits to the source repo (or the Core host file). Confirm before
  committing — that is a change to someone's git history, not just to Komodo.
- A sync run is an execution: it can touch many resources at once. Treat `run` like a batch.

## Notes

- Sync files can be split across any number of files/folders under `resource_path`.
- TOML declarations use the same schemas as the API; see
  [`../references/schemas-and-queries.md`](../references/schemas-and-queries.md) and
  `docsite/docs/automate/sync-resources.md` in the Komodo repo.
