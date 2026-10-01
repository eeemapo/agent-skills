# Declarative Resources (ResourceSync / TOML)

Use when: you want to manage resources as versioned TOML files in git (or on the Core host), diff them, and apply changes — Komodo's infrastructure-as-code path.

## What a ResourceSync does

A `ResourceSync` points at TOML file(s) that declare resources (`[[server]]`, `[[stack]]`, `[[deployment]]`, ...). Core polls the source, computes a diff against existing resources, and (on run) creates/updates/deletes to match. It can also include variables and user groups.

## Sync config keys

`CreateResourceSync` / `UpdateResourceSync` take `{name, config}` (update takes `{id, config}`):

| Key | Meaning |
|-----|---------|
| `repo` + `branch` + `git_provider` + `git_https` + `git_account` | Source git repo (or set `linked_repo` to a Komodo Repo resource) |
| `files_on_host` + `resource_path` | Files on the Core host (relative to Core `sync_directory`) |
| `managed` | Push UI/API changes back to the file/repo and commit |
| `match_tags` | Limit managed exports to resources with all these tags |
| `delete` | Delete resources not declared in the files |
| `include_resources` / `include_variables` / `include_user_groups` | What the sync owns |
| `webhook_enabled` + `webhook_secret` | Allow git push webhooks to trigger the sync |

## Direct file mode

```jsonc
POST /write { "type": "CreateResourceSync", "params": {
    "name": "prod-resources",
    "config": {
      "repo": "my-org/komodo-resources",
      "branch": "main",
      "resource_path": ["prod/"],
      "managed": true,
      "match_tags": ["prod"],
      "delete": false
    }
} }
```

Write/refresh:

```jsonc
POST /write { "type": "WriteSyncFileContents", "params": {"sync":"prod-resources","resource_path":"prod","file_path":"stacks.toml","contents":"..."} }
POST /write { "type": "RefreshResourceSyncPending", "params": {"sync": "prod-resources"} }
```

## Running and reviewing

```jsonc
// apply the pending changes
POST /execute { "type": "RunSync", "params": {"sync": "prod-resources"} }

// managed mode: commit the export back to the file/repo
POST /write { "type": "CommitSync", "params": {"sync": "prod-resources"} }

// inspect pending diffs
POST /read { "type": "GetResourceSync", "params": {"sync": "prod-resources"} }
```

`GetResourceSync` returns `ResourceSyncInfo` including:
- `resource_updates: [{target, data: {type, data}}]` where `DiffData` is `Create {name, proposed}`, `Update {proposed, current}`, or `Delete {current}`.
- `variable_updates`, `user_group_updates`, `pending_deploys`, `pending_error`, `pending_hash`/`pending_message`.
- `remote_contents` / `remote_errors` for the fetched files.

State (`ResourceSyncState`): `Syncing`, `Pending` (diffs waiting), `Ok`, `Failed`, `Unknown`.

## Export existing resources → TOML

```jsonc
POST /read { "type": "ExportAllResourcesToToml", "params": {} }
POST /read { "type": "ExportResourcesToToml",    "params": {"resources": [{"type":"Stack","id":"my-stack"}]} }
```

Use this to seed a sync file, then create/point a ResourceSync at it. `ListStacks`/`ListFull*` provide the same data in structured form.

## `CommitSync` is a write, not an execute

Unlike other "run" actions, `CommitSync` is dispatched through `/write`. All other sync operations (`RunSync`) go through `/execute`.

## Typical IaC workflow

```bash
# 1) export current state for reference
curl .../read -d '{"type":"ExportAllResourcesToToml","params":{}}'
# 2) create the sync pointing at a repo/folder (see config above)
curl .../write -d '{"type":"CreateResourceSync","params":{"name":"prod-resources","config":{...}}}'
# 3) review diffs, then apply
curl .../write -d '{"type":"RefreshResourceSyncPending","params":{"sync":"prod-resources"}}'
curl .../read  -d '{"type":"GetResourceSync","params":{"sync":"prod-resources"}}'
curl .../execute -d '{"type":"RunSync","params":{"sync":"prod-resources"}}'
```

## Safety

- With `delete: true`, resources absent from the files are **deleted**. Review `GetResourceSync` diffs before `RunSync`.
- `managed` mode writes/commits to the source repo (or Core host file). Confirm before committing.

## Notes

- Sync files can be split across any number of files/folders under `resource_path`.
- TOML declarations use the same schemas as the API; see `docsite/docs/automate/sync-resources.md` in the repo and the schema links in `references/schemas-and-queries.md`.
