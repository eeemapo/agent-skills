# Google Reader API (FreshRSS)

Base path: `<base-url>/api/greader.php`. All examples omit the base URL.

## Authentication

`POST accounts/ClientLogin`
- Form: `Email=<user>`, `Passwd=<api-password>`
- 200 body (line-oriented): `SID=...`, `LSID=...`, `Auth=<token>`
- 401 on bad credentials

Authenticated requests carry:

    Authorization: GoogleLogin auth=<token>

## Read endpoints

| Endpoint | Returns |
|---|---|
| `GET reader/api/0/user-info` | Account identity |
| `GET reader/api/0/subscription/list?output=json` | Subscribed feeds |
| `GET reader/api/0/tag/list?output=json` | Tags / labels |
| `GET reader/api/0/stream/contents/<streamId>?output=json&n=<count>` | Articles |
| `GET reader/api/0/stream/ids/<streamId>?output=json` | Item IDs only |
| `GET reader/api/0/unread-count?output=json` | Unread counts per feed |

## Write endpoints

Write actions require a per-session token first:

`GET reader/api/0/token` → a short string used as the `T=` parameter.

| Endpoint | Action |
|---|---|
| `POST reader/api/0/edit-tag` | Add/remove a tag (mark read, star) via `i=` and `a=`/`r=` |
| `POST reader/api/0/subscription/edit` | Subscribe/unsubscribe/edit a feed |
| `POST reader/api/0/mark-all-as-read` | Mark a stream read |

## Error shape

- `401 Unauthorized` — missing/invalid `Auth`, or ClientLogin rejected creds.
- `400 Bad Request` — malformed parameters.
- Non-JSON body on a JSON endpoint usually means an auth redirect.
