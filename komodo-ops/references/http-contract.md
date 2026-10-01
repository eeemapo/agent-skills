# HTTP API Contract

Core speaks a JSON "RPC-over-HTTP" protocol. The same schema powers the typed Rust/TypeScript clients, the CLI, and the UI.

## Transport

- **Method:** `POST` for `/auth`, `/read`, `/write`, `/execute`, `/terminal/execute`.
- **Method:** `GET` for `/version`, `/docs`, `/user`, `/client/*`.
- **Content-Type:** `application/json`.

## Request body

Two equivalent forms:

```jsonc
// Form A — type embedded in body
POST /read
{ "type": "ListStacks", "params": { "limit": 0 } }

// Form B — type in the path, body is just params
POST /read/ListStacks
{ "limit": 0 }
```

The `type` string is exactly the Rust request struct name (e.g. `ListStacks`, `UpdateStack`, `DeployStack`, `CreateApiKey`).

## Authentication headers

```http
Content-Type: application/json
X-Api-Key: K_...
X-Api-Secret: S_...
```

or a user JWT (obtained via `/auth` login):

```http
Authorization: <jwt>
```

API keys are the recommended mechanism for agents. A key inherits the owning user's identity and permissions.

## Endpoint map

| Path | Purpose |
|------|---------|
| `GET /version` | Core package version (no auth) |
| `GET /docs` | Interactive Scalar UI with the full OpenAPI spec inlined |
| `POST /auth` | Login, signup, and self-service API key management (`{type, params}`) |
| `GET /user` | Returns the authenticated user document |
| `POST /read` | All read requests (and `/read/{Variant}`) |
| `POST /write` | All create/update/delete/copy/rename requests (and `/write/{Variant}`) |
| `POST /execute` | Run executions (and `/execute/{Variant}`) |
| `POST /terminal/execute` | Execute a command on a terminal; returns a streamed body |
| `GET /ws` | Websocket for streaming updates/terminals |
| `GET /client/lib.js`, `/client/lib.d.ts`, `/client/types.js`, `/client/types.d.ts`, `/client/responses.js`, `/client/responses.d.ts`, `/client/terminal.js`, `/client/terminal.d.ts` | Generated TypeScript client + types |
| `/listener/{github,gitlab}/*` | Inbound git webhooks |

## Responses

- **Read/write:** JSON of the declared response type (`ListStacksResponse`, `Stack`, `GetCoreInfoResponse`, `NoData`, ...).
- **Execute:** JSON `Update`.
- **Terminal execute:** streamed raw bytes (PTY output), not JSON.

## Errors

Non-2xx responses carry:

```json
{
  "error": "top level error message",
  "trace": ["first traceback entry", "second traceback entry"]
}
```

Common statuses: `400` bad request/validation, `401` missing/invalid credentials, `403` insufficient permission, `404` not found, `500` server error. Read the `error`/`trace` fields for the real cause.

## Pagination and sorting

List endpoints generally accept:

```jsonc
{
  "query": { ... },        // resource-specific structured filter
  "page": 0,               // 0-based
  "limit": 30,              // 0 = unlimited; default = Core default_pagination_limit
  "sort_by": "Name",       // enum per resource
  "sort_desc": false
}
```

`limit: 0` returns all matching results. Keep `limit` consistent across pages.

## Executions are asynchronous

Any execution returns an `Update`:

```json
{
  "_id": {"$oid": "..."},
  "operation": "DeployStack",
  "status": "InProgress",
  "success": false,
  "target": {"type": "Stack", "id": "my-stack"},
  "logs": [{"stage": "...", "stdout": "...", "stderr": "...", "success": true}],
  "start_ts": 0,
  "end_ts": null
}
```

Poll `{"type":"GetUpdate","params":{"id":"<id>"}}` on `/read` until `status == "Complete"`, then inspect `success` and `logs`. Use `/read/ListUpdates` to page recent updates.

## Core-host tooling

- `GET <core-host>/docs` — authoritative OpenAPI reference (request fields, enums, response schemas).
- `GET <core-host>/client/types.d.ts` — generated TypeScript types for every request/response.
