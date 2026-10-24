# Users, Groups, Permissions, and Keys

**Use when** you need to create users, service users, or groups; grant or revoke access; mint
API or onboarding keys; or on-board a new server.

**Almost everything here is raw.** Only your own API keys have typed tools; the rest is the
admin namespace (`44` operations), reached with `komodo_help` → `komodo_raw`. See
[`raw-operations.md`](raw-operations.md).

## Typed: your own API keys

```
komodo_user_list_api_keys                       # name, id, created, expiry — never the secret
komodo_user_create_api_key { name, expires_in_days? }   # secret returned ONCE
komodo_user_delete_api_key { name_or_key }
```

`expires_in_days: 0` (default) means no expiry. Prefer a service-user key for automation over
lengthening your own.

## Read users and groups (raw)

```
komodo_raw { op: "ListUsers" }
komodo_raw { op: "FindUser",        args: { user: "alice" } }        # id or username
komodo_raw { op: "GetUsername",     args: { user_id: "<id>" } }
komodo_raw { op: "ListUserGroups" }
komodo_raw { op: "ListApiKeys" }                                     # keys of the calling user
komodo_raw { op: "ListApiKeysForServiceUser", args: { user_id: "<id>" } }
```

## Create / delete users (admin only)

```
komodo_raw { op: "CreateLocalUser", args: { username: "alice", password: "<pw>" } }
komodo_raw { op: "DeleteUser",      args: { user: "alice" } }
```

`CreateLocalUser` bypasses disabled self-registration. Admins delete non-admins; only a
**Super Admin** deletes an admin; nobody deletes a Super Admin or themselves.

## Service users (admin only)

Non-login identities for automation. Give them scoped permissions and issue keys:

```
komodo_raw { op: "CreateServiceUser",            args: { username: "deploy-bot", description: "CI deployer" } }
komodo_raw { op: "UpdateServiceUserDescription", args: { username: "deploy-bot", description: "…" } }
komodo_raw { op: "CreateApiKeyForServiceUser",   args: { user_id: "<id>", name: "ci", expires: 0 } }
komodo_raw { op: "DeleteApiKeyForServiceUser",   args: { key: "<key>" } }
```

Returns `{key, secret}` — the secret is shown once and is not redacted from the result, so
it lands in the transcript. Never print it further; rotate if the transcript is untrusted.

## User groups (admin only)

```
komodo_raw { op: "CreateUserGroup",        args: { name: "operators" } }
komodo_raw { op: "RenameUserGroup",        args: { id: "<id>", name: "ops" } }
komodo_raw { op: "AddUserToUserGroup",     args: { user_group: "ops", user: "alice" } }
komodo_raw { op: "RemoveUserFromUserGroup", args: { user_group: "ops", user: "alice" } }
komodo_raw { op: "SetUsersInUserGroup",    args: { user_group: "ops", users: ["alice", "bob"] } }
komodo_raw { op: "SetEveryoneUserGroup",   args: { user_group: "ops", everyone: true } }
komodo_raw { op: "DeleteUserGroup",        args: { id: "<id>" } }
```

Group permissions are inherited by members. Grants on a resource combine (`max` level + the
union of specifics).

## Permissions (admin only)

```
# base permissions for a user
komodo_raw { op: "UpdateUserBasePermissions", args: {
  user_id: "<id>", enabled: true, create_servers: false, create_builds: true } }

# admin flag — Super Admin only
komodo_raw { op: "UpdateUserAdmin", args: { user_id: "<id>", admin: true } }

# default permission on a whole resource type
komodo_raw { op: "UpdatePermissionOnResourceType", args: {
  user_target: { type: "User", id: "<user-id>" },
  resource_type: "Server",
  permission: { level: "Read", specific: ["Logs"] } } }

# permission on one specific resource
komodo_raw { op: "UpdatePermissionOnTarget", args: {
  user_target: { type: "UserGroup", id: "<group-id>" },
  resource_target: { type: "Server", id: "prod-01" },
  permission: { level: "Execute", specific: ["Terminal", "Inspect"] } } }
```

- `UserTarget` = `{type:"User"|"UserGroup", id}`.
- `ResourceTarget` = `{type:<variant>, id}` — `Server`, `Stack`, `Deployment`, `Build`,
  `Repo`, `Alerter`, `Swarm`, `Builder`, `ResourceSync`, `Procedure`, `Action`.
- `PermissionLevel`: `None` < `Read` < `Execute` < `Write`.
- `specific`: `Terminal`, `Attach`, `Inspect`, `Logs`, `Processes`.

Verify with `GetPermission {target}`, `ListPermissions` (calling user), or
`ListUserTargetPermissions {user_target}` (admin).

## Onboarding keys (admin only) — adding a server

```
komodo_raw { op: "CreateOnboardingKey", args: {
  name: "new-node", expires: 0, tags: ["prod"],
  privileged: false, copy_server: "", create_builder: false } }
```

Returns `{private_key, created}` — Core stores only the public key. Then install Periphery on
the target host with `--core-address` and `--onboarding-key`; the server appears in
`ListServers` / `komodo_server_list` and should reach state `Ok`.

`UpdateOnboardingKey` / `DeleteOnboardingKey` address the key by its **`public_key`**;
`ListOnboardingKeys` reads them.

## Safety

- Elevating to `admin` grants full control — require explicit user approval.
- Grant automation the **minimum**: e.g. `Execute` + `Terminal` on specific servers, `Write`
  only where config must change.
- Never echo returned `secret` values into logs or notes. Notes record credential **names**,
  never values.
- Deleting a user or group removes its access paths; check what that identity runs first.

## Workflow example — scoped automation identity

```
komodo_raw { op: "CreateServiceUser",          args: { username: "deploy-bot", description: "deploys prod" } }
komodo_raw { op: "CreateApiKeyForServiceUser", args: { user_id: "<id>", name: "ci", expires: 0 } }
komodo_raw { op: "UpdatePermissionOnTarget",   args: {
  user_target: { type: "User", id: "<id>" },
  resource_target: { type: "Server", id: "prod-01" },
  permission: { level: "Execute", specific: ["Logs"] } } }
```

The key goes into the credential store (never into a note or a commit), and the service-user
name into the local conventions note.
