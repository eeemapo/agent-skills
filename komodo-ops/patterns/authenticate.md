# Session Keys and Authorization

**Use when** there is no working session key, you need to know what identity is acting and
what it may do, or you need to mint/rotate a key.

## 1. Check before anything else

```
komodo_auth          # session-key status: source, user, fingerprint, loaded time
komodo_health_check  # Core + extension versions; works with no key
komodo_whoami        # effective identity + permission summary from Komodo (needs a key)
```

If `komodo_auth` reports no key, **stop and ask the operator** to run `/komodo` (or to set
`komodo.autoLoad` in `settings.json`). You have no load path — that is deliberate. A keyless
tool call returns an actionable notice, not data.

## 2. How a key gets loaded

| Route | Who does it | Notes |
|---|---|---|
| `/komodo load ops\|srv\|inf` | the operator, at a masked prompt | pasted key lives **in memory for the session**; accepts `K_<id>:<secret>` in one paste, or the key then the secret |
| `komodo.autoLoad` | the operator, in `settings.json` | loads the `auth.json` key at session start, no prompt; `"ops"` labels the source `komodo:ops` |
| `auth.json` `komodo` entry | the operator, on disk | the origin for both routes above; `$NAME` / `!command` values are allowed |

Tiers (`ops` / `srv` / `inf`) are **labels that mirror the vault tiers — not authority**.
What the key may actually do is whatever Komodo grants the account behind it; check with
`komodo_whoami`, never the tier name.

`/komodo status` shows the loaded key; `/komodo clear` drops it. Rotating a credential means
re-loading it: `/komodo clear` then `/komodo load <tier>` — or restart pi for an
auto-loaded key, since `auth.json` is read at session start.

## 3. Identity and permission model

- A key belongs to a **user** (or service user) and inherits that identity and its
  permissions. There is no separate key scope.
- `PermissionLevel` is ordered: `None` < `Read` < `Execute` < `Write`.
- **Specific** permissions: `Terminal`, `Attach`, `Inspect`, `Logs`, `Processes`.
- Admin users bypass per-resource checks; `GetCoreInfo.transparent_mode` gives everyone read
  access to everything.
- Grants on a resource combine: the `max` level plus the union of specifics.

Check a single target before operating on something you may only partly control:

```
komodo_raw { op: "GetPermission", args: { target: { type: "Stack", id: "my-stack" } } }
# -> {"level":"Write","specific":["Terminal","Logs"]}
```

Per-type grants: `ListPermissions` (the calling user), `ListUserTargetPermissions` (admin).

## 4. Status codes to expect

| Status | Meaning |
|--------|---------|
| 401 | Missing or invalid key/secret/JWT — usually no key loaded, or stale `auth.json` values |
| 403 | Authenticated but insufficient permission — raise the level, or use an admin key |
| 400 | Validation error — read the `error` + `trace` fields for the real cause |

The extension wraps API errors into readable typed messages; a 401 that drops the client
also makes `komodo_health_check` report unhealthy.

## 5. Minting keys

**For yourself** (works with the loaded key) — use the typed tools:

```
komodo_user_list_api_keys                  # name, id, created, expiry (never the secret)
komodo_user_create_api_key {name, expires_in_days?}   # returns the secret ONCE
komodo_user_delete_api_key {name_or_key}
```

The created secret is shown only once and is **not** redacted from the result, so it lands
in the transcript — treat that transcript as sensitive, and rotate if it is not trusted.
`expires_in_days: 0` means no expiry.

**For a service user** (admin only, no typed tool — see [`raw-operations.md`](raw-operations.md)):

```
komodo_raw { op: "CreateServiceUser",           args: { username: "deploy-bot", description: "CI deployer" } }
komodo_raw { op: "CreateApiKeyForServiceUser",  args: { user_id: "<id>", name: "ci", expires: 0 } }
```

Then grant least-privilege permissions with `UpdatePermissionOnTarget` /
`UpdatePermissionOnResourceType` — see [`users-and-permissions.md`](users-and-permissions.md).

## 6. JWT and password login (human / interactive flows)

Core also accepts username/password (+ OIDC/2FA) through `/auth`, returning a JWT usable
as a session key (`jwtToken`, or `Authorization` on raw HTTP). Prefer API keys for
automation: JWTs expire. Request names live under the `auth` module — find the exact
variant with `komodo_help {ns:"admin"}` or consult `GET <core-host>/docs` rather than
guessing.

## Key rules

- Never log, echo, or commit a `K_…`/`S_…` value or a JWT. Load through `auth.json` /
  `/komodo`, not by exporting into a shell.
- Least privilege: automation gets a **service user**, never an admin's personal key.
- **Creating the very first credential is not an API operation** — it needs an existing
  credential from the UI or a JWT login.
- Check `komodo_whoami` before a write/execute on a resource you do not own.
