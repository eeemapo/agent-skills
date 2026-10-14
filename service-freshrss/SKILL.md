---
name: service-freshrss
description: Operate a FreshRSS server over its Google Reader API — authenticate and read feeds, subscriptions, tags, and articles. Use when authenticating to FreshRSS, listing or reading FreshRSS subscriptions/articles, syncing or marking items, or when an agent has FreshRSS credentials but cannot reproduce the exact request shape. Covers the ClientLogin handshake, the GoogleLogin auth header, the core read endpoints, and the credential-field trap (the API password is not the login password).
license: MIT
compatibility: Client-agnostic. Requires network access to a FreshRSS instance and a credential supplied via environment variables. Uses curl.
metadata:
  version: "1.0"
  spec: Agent Skills 1.0
  upstream: FreshRSS (Google Reader API)
---

# FreshRSS Contract

FreshRSS exposes a Google Reader-compatible API under `/api/greader.php`. This
contract covers the handshake and the read verbs an agent needs most; the exact
wire format is in [`references/greader-api.md`](references/greader-api.md), and
the deterministic work is in [`scripts/freshrss.sh`](scripts/freshrss.sh).

## How to use this skill

1. Supply configuration from the environment (see **Configuration**). The
   credential source is out of scope for this skill — wherever the credential
   lives, resolve it into `FRESHRSS_API_PASSWORD` without echoing it.
2. Run a verb as a program (do **not** `source` it):
   `bash <skill-dir>/scripts/freshrss.sh {whoami|subscriptions|tags|stream}`
   (absolute path — a bare `scripts/` path fails as “not found”, which is a
   **path** problem, not an authentication failure).
3. If the verb fails, read the **Gotchas** before changing anything.

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| Authenticating / diagnosing 401 | [`patterns/authenticate.md`](patterns/authenticate.md) | Handshake and failure signals |
| Listing or reading feeds and articles | [`patterns/read-feeds.md`](patterns/read-feeds.md) | Read endpoints and paging |
| Marking read, starring, or editing feeds | [`patterns/write-actions.md`](patterns/write-actions.md) | Write verbs and the `--yes` gate |
| Exact endpoints, params, error shapes | [`references/greader-api.md`](references/greader-api.md) | Wire-level catalog |

## Verbs

    scripts/freshrss.sh --help                 # list verbs
    # read (safe)
    scripts/freshrss.sh auth                   # verify the credential
    scripts/freshrss.sh whoami                 # account identity
    scripts/freshrss.sh subscriptions          # subscribed feeds (JSON)
    scripts/freshrss.sh tags                   # tags/labels (JSON)
    scripts/freshrss.sh stream [id] [n]        # articles from a stream (JSON)
    scripts/freshrss.sh item <itemId>          # one article (JSON)
    # write (require --yes)
    scripts/freshrss.sh mark-read <id> --yes    | mark-unread <id> --yes
    scripts/freshrss.sh star <id> --yes         | unstar <id> --yes
    scripts/freshrss.sh subscribe <url> --yes   | unsubscribe <url> --yes
    scripts/freshrss.sh mark-all-read <streamId> --yes

## Configuration

Resolve everything from the environment; never hardcode.

| Variable | Meaning |
|---|---|
| `FRESHRSS_BASE_URL` | Base URL of the FreshRSS instance, e.g. `https://<host>` |
| `FRESHRSS_USER` | FreshRSS username |
| `FRESHRSS_API_PASSWORD` | The account **API password** (see Gotchas) |

`FRESHRSS_BASE_URL` is **not** a credential and is **not** a field in the vault item
— take it from the task or the host inventory. Resolve only the credential
(`username`, `API Key`) from the vault.

## Gotchas

- **Endpoint is `accounts/ClientLogin`**, not `accounts/Login`. The latter 404s.
- **The form field is `Passwd`**, not `Password`. A `Password=` field yields 401.
- **The credential is the API password, not the login password.** In FreshRSS it
  is set in the user profile (API access) and is usually a *separate* field from
  the account password — frequently labeled `API Key` or `API password`. The field
  literally named `password` is the login password and yields 401. Resolve the API
  password into `FRESHRSS_API_PASSWORD` and the username into `FRESHRSS_USER`.
- **Auth header is `Authorization: GoogleLogin auth=<token>`** — not `Bearer`.
- The token is returned by ClientLogin (the `Auth=` line), not a static key.
- **Write actions need a second, per-session token** from
  `reader/api/0/token`; the ClientLogin `Auth` token alone is insufficient.
- Failure signal: HTTP 401 means wrong credential or wrong request shape; a
  `Passwd` typo and a wrong password look identical — check the field name first.

## Safety

Read verbs are safe. **Write verbs require `--yes`**: `mark-read` / `mark-unread`
/ `star` / `unstar` / `subscribe` / `unsubscribe` / `mark-all-read` refuse to run
without it (exit 3). Pass `--yes` only after the user has explicitly approved the
specific change. Writes use the per-session action token from
`reader/api/0/token`; the script fetches it automatically.
