# Manage Resources (CRUD)

Use when: you need to create, update, copy, rename, or delete any Komodo resource, or change tags/variables/providers.

## Write request shape

```http
POST /write
{ "type": "UpdateStack", "params": { "id": "my-stack", "config": { "branch": "release" } } }
```

Every `X` resource type exposes a consistent verb set. Unless noted, `Create`/`Copy`/`Update` return the full resource, `Delete` returns the deleted resource, and `Rename` returns an `Update`.

| Verb | Params | Notes |
|------|--------|-------|
| `CreateX` | `{name, config?}` | `config` is a partial config |
| `CopyX` | `{name, id}` | clone an existing resource under a new name |
| `UpdateX` | `{id, config}` | **partial config merge** (only sent fields change) |
| `DeleteX` | `{id}` | irreversible |
| `RenameX` | `{id, name}` | returns `Update` |

Resource types: `Swarm`, `Server`, `Stack`, `Deployment`, `Build`, `Repo`, `Procedure`, `Action`, `ResourceSync`, `Builder`, `Alerter`.

## Examples

```bash
# Create
curl -sS $CORE/write -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"CreateStack","params":{"name":"my-stack","config":{"server_id":"<server-id>"}}}'

# Update (merges): only branch changes, everything else preserved
curl -sS $CORE/write -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"UpdateStack","params":{"id":"my-stack","config":{"branch":"release"}}}'

# Rename, then delete
curl .../write -d '{"type":"RenameStack","params":{"id":"my-stack","name":"my-stack-v2"}}'
curl .../write -d '{"type":"DeleteStack","params":{"id":"my-stack-v2"}}'
```

## Shared meta: description / template / tags

Any resource type uses the same endpoint:

```jsonc
POST /write { "type": "UpdateResourceMeta", "params": {
    "target": {"type": "Stack", "id": "my-stack"},
    "description": "Prod web stack",
    "template": false,
    "tags": ["prod", "web"]     // exact set to apply; null = no change
} }
```

## Resource-specific writes

| Type | Endpoints |
|------|-----------|
| Stack | `WriteStackFileContents` `{stack, file_path, contents}`, `RefreshStackCache` `{stack}`, `CheckStackForUpdate` `{stack,...}`, `BatchCheckStackForUpdate` `{pattern, tags?}` |
| Deployment | `CreateDeploymentFromContainer`, `CheckDeploymentForUpdate`, `BatchCheckDeploymentForUpdate` |
| Build | `WriteBuildFileContents`, `RefreshBuildCache` |
| Repo | `RefreshRepoCache` |
| ResourceSync | `WriteSyncFileContents`, `CommitSync`, `RefreshResourceSyncPending` |
| Server | `CreateNetwork`, `UpdateServerPublicKey`, `RotateServerKeys` |

`Check*ForUpdate` inspects images/repo contents for available updates and can auto-redeploy when `auto_update` is enabled (see `patterns/run-executions.md`).

## Variables

```jsonc
POST /write { "type": "CreateVariable",   "params": {"name":"MY_VAR","value":"x","description":"","is_secret":false} }
POST /write { "type": "UpdateVariableValue", "params": {"name":"MY_VAR","value":"y"} }
POST /write { "type": "UpdateVariableIsSecret", "params": {"name":"MY_VAR","is_secret":true} }
POST /write { "type": "UpdateVariableDescription", "params": {"name":"MY_VAR","description":"..."} }
POST /write { "type": "DeleteVariable", "params": {"name":"MY_VAR"} }
```

Variables referenced in resource configs are interpolated by Core at execution time. **Admin only.**

## Tags

```jsonc
POST /write { "type": "CreateTag",     "params": {"name":"prod","color":"Red"} }
POST /write { "type": "RenameTag",     "params": {"id":"<tag-id>","name":"production"} }
POST /write { "type": "UpdateTagColor","params": {"tag":"production","color":"Green"} }
POST /write { "type": "DeleteTag",     "params": {"id":"<tag-id>"} }   // also detaches from resources
```

Tags attach to resources via `UpdateResourceMeta` (`tags`) or resource configs. In `ResourceQuery`, pass tag **ids or names** with `tag_behavior` `All`/`Any`.

## Git / image-registry provider accounts (admin only)

```jsonc
POST /write { "type": "CreateGitProviderAccount",        "params": {"account": {...}} }
POST /write { "type": "UpdateGitProviderAccount",        "params": {"id":"...", "account": {...}} }
POST /write { "type": "DeleteGitProviderAccount",        "params": {"id":"..."} }
POST /write { "type": "CreateImageRegistryAccount",      "params": {"account": {...}} }
POST /write { "type": "UpdateImageRegistryAccount",      "params": {"id":"...", "account": {...}} }
POST /write { "type": "DeleteImageRegistryAccount",      "params": {"id":"..."} }
```

See also reads `ListGitProviderAccounts`, `ListImageRegistryAccounts`, and the config-derived `ListGitProvidersFromConfig`, `ListImageRegistriesFromConfig`, `ListSecrets`.

## Alerts

```jsonc
POST /write { "type": "CloseAlert", "params": {"id": "<alert-id>"} }
```

## Key rules

- **Read-modify-write:** fetch with `GetX`/`ListFullX`, change only what you mean to, then `UpdateX`. The merge is field-level on the partial config.
- **Admin-only** endpoints (`CreateVariable`, tags are generally open; providers/variables/deletes of users are admin) will 403 for non-admin keys.
- Resource names are unique per type and can be used in place of ids, but store the stable `id`.

## Workflow example

```bash
# ensure a tag exists, apply it, and set a description
curl .../write -d '{"type":"CreateTag","params":{"name":"prod","color":"Red"}}'
curl .../write -d '{"type":"UpdateResourceMeta","params":{"target":{"type":"Stack","id":"my-stack"},"tags":["prod"],"description":"Prod web"}}'
```
