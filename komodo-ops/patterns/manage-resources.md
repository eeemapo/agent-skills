# Manage Resources (CRUD)

**Use when** you need to create, update, copy, rename, or delete a Komodo resource, or change
tags, variables, or metadata.

## Typed writes

Every resource domain with a typed tool exposes two verbs:

| Verb | Shape | Notes |
|------|-------|-------|
| `komodo_<resource>_apply` | `action="create"` → needs `name`; `action="update"` → needs the resource id/name | **PATCH-style partial merge**: only the fields you send change |
| `komodo_<resource>_delete` | the resource id/name | irreversible; confirm with the user first |

Domains with typed `_apply`/`_delete`: `server`, `swarm`, `stack`, `deployment`, `build`,
`repo`, `procedure`, `action`, `alerter`, `resource_sync`, `builder`, `variable`, `tag`.

## Create vs update

```
# create — name plus the source of truth for that resource type
komodo_stack_apply { action: "create", name: "my-stack", server_id: "prod-01",
                     config: { repo: "org/repo", branch: "main", run_directory: "my-stack" } }

# update — only what you mean to change; everything else is preserved
komodo_stack_apply { action: "update", stack: "my-stack", config: { branch: "release" } }
```

**Read-modify-write:** fetch with `_info`, change only the intended fields, then `_apply`.
The merge is field-level on the partial config; there is no race protection, so a concurrent
editor's change to a field you also sent will be lost.

Notable per-type config lives in the tool descriptions — read them before a first create.
Two that bite:

- **Stacks** take their content from one of three sources (`file_contents` for inline,
  `repo` + `branch` for repo-backed, `files_on_host` for host files) plus `environment`,
  `run_directory`, `auto_pull`, `auto_update`, `destroy_before_deploy`, `webhook_*`, and
  `compose_cmd_wrapper`. Editing the *files* of an existing stack is a different operation —
  see the local conventions in `SKILL.md` (`14.13`).
- **Deployments** accept `image` as a plain string or as `{ type: "Image"|"Build", params }`;
  a `Build` image ties the deployment to a Komodo Build's version, and `redeploy_on_build`
  makes the build redeploy it.

## Copy and rename

Typed only for builders: `komodo_builder_copy { name, id }` and
`komodo_builder_rename { builder, name }`.

For everything else, use raw — `CopyX {name, id}` clones under a new name and
`RenameX {id, name}` returns an `Update`:

```
komodo_raw { op: "CopyStack",   args: { name: "my-stack-v2", id: "my-stack" } }
komodo_raw { op: "RenameStack", args: { id: "my-stack-v2", name: "my-stack-prod" } }
```

## Shared metadata: description / template / tags

Every resource type uses one operation, `UpdateResourceMeta`, with a `target`:

```
komodo_raw { op: "UpdateResourceMeta", args: {
  target: { type: "Stack", id: "my-stack" },
  description: "Prod web stack",
  template: false,
  tags: ["prod", "web"]        // exact set to apply; null = no change
} }
```

`target.type` is the resource kind (`Stack`, `Deployment`, `Server`, `Build`, `Repo`,
`Procedure`, `Action`, `ResourceSync`, `Builder`, `Alerter`, `Swarm`, `Variable`, …).

## Resource-specific writes (raw)

These have no typed tool:

| Type | Operations |
|------|-----------|
| Stack | `WriteStackFileContents {stack, file_path, contents}`, `RefreshStackCache`, `CheckStackForUpdate`, `BatchCheckStackForUpdate` |
| Deployment | `CreateDeploymentFromContainer`, `CheckDeploymentForUpdate`, `BatchCheckDeploymentForUpdate` |
| Build | `WriteBuildFileContents`, `RefreshBuildCache` |
| Repo | `RefreshRepoCache` |
| ResourceSync | `WriteSyncFileContents`, `CommitSync`, `RefreshResourceSyncPending` |
| Server | `CreateNetwork`, `UpdateServerPublicKey`, `RotateServerKeys` |
| Alert | `CloseAlert {id}` |

`Check*ForUpdate` inspects images/repo contents for available updates and can auto-redeploy
when the resource has `auto_update` enabled (see [`run-executions.md`](run-executions.md)).
`Write*FileContents` commits to the backing repo **asynchronously** — read the local
conventions before relying on the server's local checkout.

## Variables

Typed (`komodo_variable_*`), with one wrinkle: on update, each of `value`, `description`,
and `is_secret` is a **separate** API call, so pass only the ones you intend to change.

```
komodo_variable_apply { action: "create", name: "MY_VAR", value: "x", is_secret: false }
komodo_variable_apply { action: "update", name: "MY_VAR", value: "y" }
komodo_variable_list
```

Variables referenced in resource configs as `[[variable.name]]` are interpolated by Core at
execution time. **Admin only.** Deleting one breaks any stack/deployment that references it.

## Tags

```
komodo_tag_apply { action: "create", name: "prod", color: "Red" }
komodo_tag_apply { action: "update", tag: "prod", name: "production", color: "Green" }
komodo_tag_delete { tag: "production" }        # also detaches it from every resource
```

Renaming and recolouring are separate API calls (there is no combined update endpoint), so
`action="update"` issues one call per change. Colors are named `<Shade><Base>` (e.g.
`Blue`, `DarkRed`, `LightGreen`). In queries, pass tag **ids or names** with `tag_behavior`
`All` (default) or `Any`.

## Admin-only writes (raw)

Providers, users, groups, permissions, onboarding keys, and swarm configs/secrets are admin
operations with no typed tool — reach them through `komodo_help` → `komodo_raw`:

| Area | Operations |
|------|-----------|
| Git / registry accounts | `Create`/`Update`/`DeleteGitProviderAccount`, `Create`/`Update`/`DeleteImageRegistryAccount` |
| Users & groups | `CreateLocalUser`, `DeleteUser`, `CreateServiceUser`, `CreateUserGroup`, `AddUserToUserGroup`, `SetUsersInUserGroup`, … |
| Permissions | `UpdateUserBasePermissions`, `UpdateUserAdmin`, `UpdatePermissionOnResourceType`, `UpdatePermissionOnTarget` |
| Swarm configs/secrets | `CreateSwarmConfig` / `RotateSwarmConfig` / `RemoveSwarmConfigs`, `CreateSwarmSecret` / `RotateSwarmSecret` / `RemoveSwarmSecrets` |

`UpdateResourceMeta`, tags, and most resource CRUD are open to any writer; variables,
provider accounts, user/permission changes, and user deletion are admin. A non-admin key
gets **403**. See [`users-and-permissions.md`](users-and-permissions.md).

## Key rules

- Partial merge: send only what changes; read before you write.
- Resolve the exact id first (`_list`/`_info`); names work for most fields but store the id.
- `_delete` is irreversible — confirm intent, and check nothing depends on the resource.
- Never echo returned credentials (`komodo_user_create_api_key`, `CreateApiKeyForServiceUser`).
- After a config change, an execution is usually required to make it real — see
  [`run-executions.md`](run-executions.md).
