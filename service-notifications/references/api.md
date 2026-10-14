# Bark + Apprise — wire catalog

## Bark

Base: `$BARK_URL`. Auth: the **device key** in the payload (no header).

| Verb | Method | Path |
|------|--------|------|
| ping | GET | `/ping` → `{"code":200,"message":"pong","timestamp":...}` |
| info | GET | `/info` → `{"devices":N,"version":"v2.3.7",...}` |
| push | POST | `/push` |

Push payload:

    {"device_key":"...","title":"...","body":"...","level":"active","group":"pi"}

`level` ∈ `active`, `timeSensitive`, `passive`, `critical`.
Shorthand URL form also exists: `POST /{device_key}/{title}/{body}`.

## Apprise

Base: `$APPRISE_URL`.

| Verb | Method | Path |
|------|--------|------|
| notify (stateless) | POST | `/notify` |
| notify (saved key) | POST | `/notify/{key}` |
| status | GET | `/status` |

Form-encoded body: `title`, `body`, `type` (`info|success|warning|failure`).
**Response is plain text** (`Sent Bark notification to ****`), not JSON.

## Errors

| Code | Meaning |
|------|---------|
| 200 | accepted for delivery |
| 400 | malformed payload (missing title/body/device_key) |
| 500 | destination rejected the message |
