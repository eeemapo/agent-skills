---
name: service-notifications
description: Send human-facing notifications through a self-hosted Bark (APNs push) server or an Apprise hub. Use when an agent needs to reach a person — "ping me when this finishes", "tell me if it fails" — or to check that the notification path is alive. Covers the Bark push API (device-key auth), the Apprise stateless /notify endpoint, and the delivery-type vocabulary. Read verbs are safe; the send verbs are user-visible side effects that are not gated because reaching the human is the point.
license: MIT
compatibility: Client-agnostic. Requires network access to a Bark server and/or an Apprise hub, with a Bark device key in the environment. Uses curl and jq.
metadata:
  version: "1.0"
  spec: Agent Skills 1.0
  upstream: Bark push API + Apprise API
---

# Notifications Contract

Two paths reach the same iPhone/iPad: **Bark** (direct APNs push) and **Apprise**
(a hub that fans out to configured destinations). Deterministic work lives in
[`scripts/notify.sh`](scripts/notify.sh); endpoints are in
[`references/api.md`](references/api.md).

## How to use this skill

1. Supply configuration from the environment (see **Configuration**). Resolve the
   device key into `BARK_KEY` **without echoing it**.
2. Run a verb as a program (do **not** `source` it):
   `bash scripts/notify.sh <verb> [args]`.
3. Keep messages short — these land on a phone lock screen.

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| Sending a push | [`patterns/send.md`](patterns/send.md) | Titles, levels, and when to use which path |
| Endpoints and payloads | [`references/api.md`](references/api.md) | Wire-level catalog |

## Verbs

    scripts/notify.sh --help
    # read (safe)
    scripts/notify.sh ping                          # is the Bark server up?
    scripts/notify.sh info                          # Bark version + device count
    # send (user-visible)
    scripts/notify.sh bark <title> <body> [--level active|timeSensitive|passive] [--group G]
    scripts/notify.sh apprise <title> <body> [--type info|success|warning|failure]

## Configuration

| Variable | Required | Meaning |
|----------|----------|---------|
| `BARK_URL` | yes | Bark server base, e.g. `https://bark.example.invalid` |
| `BARK_KEY` | yes | Bark device key (the only credential Bark uses) |
| `APPRISE_URL` | for `apprise` | Apprise base, e.g. `https://notifications.example.invalid` |

The `*_URL` values are **not** credentials and are **not** fields in the vault item
— take them from the task or the host inventory. Resolve only `BARK_KEY` from
the vault.

## Gotchas

- **These are not gated behind `--yes`** — unlike other service contracts — because
  notifying a human is the entire purpose. But they are *user-visible*: do not
  send one per step; send one at the end, or on failure.
- **Bark authenticates with the device key alone.** There is no username/password;
  `BARK_KEY` is the whole credential. The URL form is
  `POST /push` with `{"device_key": ..., "title": ..., "body": ...}`.
- **Apprise returns plain text**, not JSON: HTTP 200 with a log line such as
  `Sent Bark notification to ****`. Do not try to parse it as JSON.
- **`--level` changes interruption behaviour**: `active` (default) wakes the
  screen, `timeSensitive` breaks through Focus, `passive` is silent.
- Multiple Bark devices may be registered; the push goes to the device matching
  the key, not to all of them.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | success |
| 1 | configuration or HTTP error |
| 2 | unknown verb |
