# Users, Groups, Permissions, and Keys

Use when: you need to create users, service users, or groups; grant/revoke access; mint API or onboarding keys; or on-board a new server.

## Read users and groups

```jsonc
POST /read { "type": "FindUser",   "params": {"user": "alice"} }        // by id or username
POST /read { "type": "GetUsername","params": {"user_id": "<id>"} }
POST /read { "type": "ListUsers",  "params": {} }
POST /read { "type": "ListUserGroups", "params": {} }
POST /read { "type": "ListApiKeys", "params": {} }
POST /read { "type": "ListApiKeysForServiceUser", "params": {"user_id": "<id>"} }
```

## Create / delete users (admin only)

```jsonc
POST /write { "type": "CreateLocalUser", "params": {"username":"alice","password":"<pw>"} }
POST /write { "type": "DeleteUser",      "params": {"user":"alice"} }
```

`CreateLocalUser` bypasses disabled self-registration; `/auth` also has self-signup/login flows. Admins can delete non-admins; only a **Super Admin** can delete an admin; nobody can delete a Super Admin or themselves.

## Service users (admin only)

Service users are non-login identities for automation. Give them scoped permissions and issue API keys.

```jsonc
POST /write { "type": "CreateServiceUser",            "params": {"username":"deploy-bot","description":"CI deployer"} }
POST /write { "type": "UpdateServiceUserDescription", "params": {"username":"deploy-bot","description":"..."} }
POST /write { "type": "CreateApiKeyForServiceUser",   "params": {"user_id":"<id>","name":"ci","expires":0} }
POST /write { "type": "DeleteApiKeyForServiceUser",   "params": {"key":"<key>"} }
```

Returns `{key, secret}` — the secret is shown once.

## User groups (admin only)

```jsonc
POST /write { "type": "CreateUserGroup",       "params": {"name":"operators"} }
POST /write { "type": "RenameUserGroup",       "params": {"id":"<id>","name":"ops"} }
POST /write { "type": "AddUserToUserGroup",    "params": {"user_group":"ops","user":"alice"} }
POST /write { "type": "RemoveUserFromUserGroup","params": {"user_group":"ops","user":"alice"} }
POST /write { "type": "SetUsersInUserGroup",   "params": {"user_group":"ops","users":["alice","bob"]} }
POST /write { "type": "SetEveryoneUserGroup",  "params": {"user_group":"ops","everyone":true} }
POST /write { "type": "DeleteUserGroup",       "params": {"id":"<id>"} }
```

Group permissions are inherited by members. Grants on a resource combine (`max` level + union of specifics).

## Permissions (admin only)

```jsonc
// base permissions for a user
POST /write { "type": "UpdateUserBasePermissions", "params": {
    "user_id":"<id>", "enabled":true, "create_servers":false, "create_builds":true } }

// admin flag (Super Admin only)
POST /write { "type": "UpdateUserAdmin", "params": {"user_id":"<id>","admin":true} }

// default permission on a whole resource type
POST /write { "type": "UpdatePermissionOnResourceType", "params": {
    "user_target": {"type":"User","id":"<user-id>"},
    "resource_type": "Server",
    "permission": {"level":"Read","specific":["Logs"]} } }

// permission on one specific resource
POST /write { "type": "UpdatePermissionOnTarget", "params": {
    "user_target": {"type":"UserGroup","id":"<group-id>"},
    "resource_target": {"type":"Server","id":"prod-01"},
    "permission": {"level":"Execute","specific":["Terminal","Inspect"]} } }
```

- `UserTarget` = `{"type":"User","id":...}` or `{"type":"UserGroup","id":...}`.
- `ResourceTarget` = `{"type":<ResourceTargetVariant>,"id":...}` e.g. `Server`, `Stack`, `Deployment`, `Build`, `Repo`, `Alerter`, `Swarm`, `Builder`, `ResourceSync`, `Procedure`, `Action`.
- `PermissionLevel`: `None` < `Read` < `Execute` < `Write`.
- `specific`: `Terminal`, `Attach`, `Inspect`, `Logs`, `Processes`.

Verify with reads `GetPermission` `{target}`, `ListPermissions` (calling user), `ListUserTargetPermissions` `{user_target}` (admin).

## API keys

- **Self** key via `/auth`: `{"type":"CreateApiKey","params":{"name":"agent","expires":0}}`.
- **Service user** key via `/write/CreateApiKeyForServiceUser` (admin).
- List/inspect via `ListApiKeys`, `ListApiKeysForServiceUser`.
- `expires` = unix ms; `0` = never.

## Onboarding keys (admin only) — adding a server

```jsonc
POST /write { "type": "CreateOnboardingKey", "params": {
    "name":"new-node", "expires":0, "tags":["prod"],
    "privileged":false, "copy_server":"", "create_builder":false } }
```

Returns `{private_key, created}` (the key is not stored server-side, only its public key). Then install Periphery on the target host with `--core-address` and `--onboarding-key`; the new server appears in `ListServers` and should reach state `Ok`. `UpdateOnboardingKey`/`DeleteOnboardingKey` use the key's `public_key`; `ListOnboardingKeys` reads them.

## Safety

- Elevating to `admin` grants full control; require explicit approval.
- Grant automation the **minimum** level: e.g. `Execute` + `Terminal` on specific servers, `Write` only where config must change.
- Never print returned `secret` values into shared logs.

## Workflow example — scoped automation identity

```bash
# create service user, key, and scoped permissions
curl .../write -d '{"type":"CreateServiceUser","params":{"username":"deploy-bot","description":"deploys prod"}}'
curl .../write -d '{"type":"CreateApiKeyForServiceUser","params":{"user_id":"<id>","name":"ci","expires":0}}'
curl .../write -d '{"type":"UpdatePermissionOnTarget","params":{"user_target":{"type":"User","id":"<id>"},"resource_target":{"type":"Server","id":"prod-01"},"permission":{"level":"Execute","specific":["Terminal","Logs"]}}}'
```
