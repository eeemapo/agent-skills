# Authenticate and Authorize

Use when: you need working credentials for Komodo Core, want to know which identity/permissions a key has, or need to create/rotate keys.

## 1. API key + secret (preferred for agents)

Every request carries:

```http
Content-Type: application/json
X-Api-Key: K_...
X-Api-Secret: S_...
```

Keys are always paired (`K_...` public identifier, `S_...` secret; only the secret is stored hashed). A key belongs to a **user** and inherits that user's permissions.

```bash
curl -sS https://komodo.example.com/read \
  -H 'Content-Type: application/json' \
  -H "X-Api-Key: $KOMODO_API_KEY" \
  -H "X-Api-Secret: $KOMODO_API_SECRET" \
  -d '{"type":"GetCoreInfo","params":{}}'
```

The bundled `scripts/komodo_api.py` wraps this: it reads the same env vars, posts `{type, params}`, and prints JSON.

## 2. Confirm identity and permissions

```bash
# Who is this key?
curl -sS https://komodo.example.com/user -H "X-Api-Key: $K" -H "X-Api-Secret: $S"

# What may it do on a specific resource?
curl -sS https://komodo.example.com/read \
  -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"GetPermission","params":{"target":{"type":"Stack","id":"my-stack"}}}'
# -> {"level":"Write","specific":["Terminal","Logs"]}
```

`PermissionLevel` is ordered: `None` < `Read` < `Execute` < `Write`. Specific permissions: `Terminal`, `Attach`, `Inspect`, `Logs`, `Processes`. Admin users bypass per-resource checks.

## 3. Create an API key

**For yourself** (works with an existing API key or a JWT):

```bash
curl -sS https://komodo.example.com/auth \
  -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"CreateApiKey","params":{"name":"agent","expires":0}}'
# -> {"key":"K_...","secret":"S_..."}   (secret shown once)
```

`expires` is a unix-millisecond timestamp; `0` means no expiry.

**For a service user** (admin only, via `/write`):

```bash
# 1) create the service user
curl .../write -d '{"type":"CreateServiceUser","params":{"username":"deploy-bot","description":"CI deployer"}}'
# 2) mint a key for it (use the returned user id)
curl .../write -d '{"type":"CreateApiKeyForServiceUser","params":{"user_id":"<id>","name":"ci","expires":0}}'
```

Then grant the service user permissions with `UpdatePermissionOnResourceType` / `UpdatePermissionOnTarget` (see `patterns/users-and-permissions.md`).

## 4. JWT login (human / interactive flows)

Core also supports username/password (+ OIDC/2FA) login through `/auth`, returning a JWT usable as `Authorization: <jwt>`. Request type names live under the auth module; `SignUpLocalUser` and `CreateApiKey` are confirmed members. Consult `GET <core-host>/docs` for the exact login/signup variants instead of guessing. Prefer API keys for automation; JWTs expire.

## 5. Status codes to expect

| Status | Meaning |
|--------|---------|
| 401 | Missing or invalid key/secret/JWT |
| 403 | Authenticated but insufficient permission (raise level or use an admin key) |
| 400 | Validation error — read `error` + `trace` |

## Key rules

- Never log or commit secrets. Inject them via environment/secret store.
- Least privilege: use a **service user** for automation, not an admin's personal key.
- Check `GetPermission` before write/execute on a resource you don't own.
- If Core is in `transparent_mode` (see `GetCoreInfo`), all users get read access to all resources.

## Workflow example

```bash
# verify, then make a scoped check before acting
curl -sS $CORE/user            -H "X-Api-Key: $K" -H "X-Api-Secret: $S"
curl -sS $CORE/read \
  -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"GetPermission","params":{"target":{"type":"Server","id":"prod-01"}}}'
```
