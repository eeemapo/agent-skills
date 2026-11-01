---
name: service-calibre
description: Operate a Calibre library server over its content-server API — authenticate with HTTP Digest, list libraries, search and read metadata, and (behind an explicit approval gate) add, remove, or re-tag books with calibredb. Use when working with a Calibre library server, when an agent has Calibre credentials but cannot reproduce the exact request shape, when books must be counted, listed, added, or removed, or when a Calibre call fails with 400 "Unsupported authentication method" or 403 "Anonymous users are not allowed to make changes". Covers the Digest-not-Basic trap, the desktop-GUI-vs-content-server port split, the /cdb command API, and the fact that remove deletes book files irreversibly.
license: MIT
compatibility: Client-agnostic. Requires network access to a Calibre content server, a credential supplied via environment variables, and calibredb on PATH (the calibre package); the raw verbs also use curl and jq.
metadata:
  version: "1.0"
  spec: Agent Skills 1.0
  upstream: Calibre content server (calibredb / CDB API)
---

# Calibre Contract

A Calibre deployment serves a library through a **content server** that speaks
HTTP Digest auth and accepts the same commands as the local `calibredb` CLI.
This contract covers the endpoint shape, the verbs an agent needs, and the traps.
It assumes you already have the URL and the credential — acquiring them is the
caller's job, not this skill's. Wire format is in
[`references/cdb-api.md`](references/cdb-api.md); the deterministic work is in
[`scripts/calibre.sh`](scripts/calibre.sh).

## How to use this skill

1. Put `CALIBRE_URL`, `CALIBRE_USER` and `CALIBRE_PASSWORD` in the environment
   (see **Environment**).
2. Run a verb as a program (do **not** `source` it):
   `bash /home/sysops/.pi/agent/skills/service-calibre/scripts/calibre.sh {auth|libraries|list|count|…}`
   (absolute path — a bare `scripts/` path fails as "not found", which is a
   **path** problem, not an authentication failure).
3. If a verb fails, read **Gotchas** before changing anything.

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| Authenticating, or 400/401/403 | [`patterns/authenticate.md`](patterns/authenticate.md) | Digest trap and failure signals |
| Listing, searching, counting books | [`patterns/read-library.md`](patterns/read-library.md) | Read verbs and the counting trap |
| Adding, removing, editing books | [`patterns/write-actions.md`](patterns/write-actions.md) | The `--yes` gate and irreversibility |
| Exact endpoints and payload shapes | [`references/cdb-api.md`](references/cdb-api.md) | Wire-level catalog |

## Verbs

    scripts/calibre.sh --help
    # read (safe)
    scripts/calibre.sh auth [--library L]           # probe read access to a library
    scripts/calibre.sh libraries                    # library ids + server default (JSON)
    scripts/calibre.sh list [--search Q] [--fields title,authors] [--for-machine]
    scripts/calibre.sh search <query>               # matching book ids
    scripts/calibre.sh show <id>                    # full metadata
    scripts/calibre.sh count                        # book count (id-based, see Gotchas)
    scripts/calibre.sh categories                   # category/value counts
    # write (require --yes AND --library)
    scripts/calibre.sh add <file> --library L --yes
    scripts/calibre.sh remove <id> [<id>…] --library L --yes
    scripts/calibre.sh set-metadata <id> --field title:New --library L --yes
    scripts/calibre.sh add-format <id> <file> --library L --yes
    scripts/calibre.sh remove-format <id> <ext> --library L --yes
    # escape hatch (see Gotchas)
    scripts/calibre.sh [--library L] [--yes] raw <command> [args…]

Every verb takes `--library <id>`; reads default to the server's default
library, **writes must name it** (the script refuses otherwise). `raw` forwards
everything after the command to `calibredb` verbatim, so it reaches the
commands this script does not wrap — at the cost of script options having to come
*before* it.

## Environment

Three variables, supplied by the caller. This skill does not acquire them.

| Variable | Meaning |
|---|---|
| `CALIBRE_URL` | Content-server base URL **with** scheme, no trailing slash |
| `CALIBRE_USER` | Content-server user |
| `CALIBRE_PASSWORD` | That user's password |

`CALIBRE_URL` must point at the **content server**, not the desktop GUI. They are
different ports on the same host and only one speaks this API — the GUI's
`/ajax/*` 404s. See [`references/cdb-api.md`](references/cdb-api.md#topology).

## Gotchas

- **Auth is HTTP Digest, not Basic.** Basic produces
  `400 Unsupported authentication method` — a *request-shape* error that looks
  nothing like a bad password. Use `curl --digest`, or `calibredb` (which
  negotiates it for you). There is no `/ajax/login` endpoint to fall back on.
- **Do not point `CALIBRE_URL` at the GUI port.** The desktop GUI (a Selkies/VNC
  web wrapper with `nginx` in front) is a different listener from the content
  server; its `/ajax/*` 404s. A 404 on every `/ajax/*` path is a wrong-port
  symptom, not a wrong-credential one.
- **Counting with `wc -l` overstates the library.** `calibredb list` wraps long
  titles onto extra lines, so a non-empty-line count can be ~1.7× the real number.
  Use `scripts/calibre.sh count`, which asks for `--for-machine` JSON and measures
  the array.
- **`calibredb search` prints ids**, not titles — pipe through `show` or use
  `list --search <query>` for a table.
- **Anonymous reads may be allowed.** A server with auth enabled still answers
  `401` without credentials, but a server with anonymous access enabled answers
  reads fine and only refuses writes (`403 Anonymous users are not allowed to
  changes`). A read "working" therefore does not prove the credential is valid,
  and `auth ok` reports only that reads work — prove the credential with a
  write-capability probe ([`patterns/authenticate.md`](patterns/authenticate.md)).
- **A `200` from `/cdb/cmd/*` is not success.** Argument errors come back as
  HTTP 200 with `{"err": …}` in the body.
- **Version skew is tolerable for these verbs.** A 6.x `calibredb` drives a 9.x
  content server for list/add/remove/metadata; newer commands may not exist on an
  older client.
- `--password` puts the value in the child's argv briefly. Never enable `set -x`
  or shell tracing around these calls.
- **`raw` keeps the gate and refuses six commands.** `catalog`,
  `add_custom_column`, `remove_custom_column`, `restore_database`,
  `check_library` and `backup_metadata` cannot run against a remote library;
  `raw` refuses them because the *server* does not — that check is client-side
  only ([`references/cdb-api.md`](references/cdb-api.md)). Anything not on the
  read-only allowlist still needs `--yes` and `--library`.

## Safety

Read verbs are safe. **Write verbs require `--yes`, and require `--library`** —
the script refuses without both (exit 3). `remove` deletes the book's records
*and its format files from disk*, with no trash and no undo; `remove-format`
deletes a single file; `set-metadata` rewrites database fields. Pass `--yes`
only after the user approved the specific change, and show the before/after
(`show <id>`) rather than chaining bulk edits.
