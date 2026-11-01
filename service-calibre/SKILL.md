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
This contract covers the credential, the endpoint, the verbs an agent needs, and
the traps. Wire format is in [`references/cdb-api.md`](references/cdb-api.md);
the deterministic work is in [`scripts/calibre.sh`](scripts/calibre.sh).

## How to use this skill

1. Resolve the credential from the vault, and the base URL from the stack (see
   **Configuration**) — one `vault_run` supplies the credential.
2. Run a verb as a program (do **not** `source` it):
   `bash <skill-dir>/scripts/calibre.sh {auth|libraries|list|count|…}`
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
    scripts/calibre.sh auth                        # verify the credential
    scripts/calibre.sh libraries                    # library ids + server default (JSON)
    scripts/calibre.sh list [--limit 20] [--search Q] [--fields title,authors]
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

Every verb takes `--library <id>`; reads default to the server's default
library, **writes must name it** (the script refuses otherwise).

## Configuration

The credential lives in the vault; the base URL comes from the deployment's own
config. Never hardcode either.

| Variable | Source | Meaning |
|---|---|---|
| `CALIBRE_URL` | the stack's `ts/ts-serve.json` (see below) | Content-server base URL **with** scheme, no trailing slash |
| `CALIBRE_USER` | vault field `username` | Content-server user |
| `CALIBRE_PASSWORD` | vault field `password` | That user's password |

**Resolve `CALIBRE_URL` from the stack, not from memory.** The content server
is not necessarily on 443: the stack publishes it as a separate listener, and the
443 listener is often the *desktop GUI* instead. Read the stack's serve config —
via Komodo (`komodo_stack_info` for the stack, then the repo file
`<stack>/ts/ts-serve.json`) or from the repo checkout — and take:

- the hostname from the entry that terminates TLS for the stack
  (`TerminateTLS` / the `Web` key), and
- the published port from the `TCP` entry whose `TCPForward` targets the
  content server's internal port (calibre's content server listens on **8081**
  inside the container; the GUI wrapper listens on 8080).

A worked example from this homelab (`calibre/ts/ts-serve.json`):

    "TCP": { "8082": { "TCPForward": "localhost:8081",
                       "TerminateTLS": "<stack-hostname>" } }
    →  CALIBRE_URL="https://<stack-hostname>:8082"

One `vault_run` supplies the credential (base URL passed separately because the
vault item carries no URL field):

    vault_run({
      "vault": "<vault-tier>",
      "item": "calibre",
      "fields": [{"name": "CALIBRE_USER", "field": "username"},
                 {"name": "CALIBRE_PASSWORD", "field": "password"}],
      "command": "CALIBRE_URL='https://<stack-hostname>:8082' bash <skill-dir>/scripts/calibre.sh count --library import"})

## Gotchas

- **Auth is HTTP Digest, not Basic.** Basic produces
  `400 Unsupported authentication method` — a *request-shape* error that looks
  nothing like a bad password. Use `curl --digest`, or `calibredb` (which
  negotiates it for you). There is no `/ajax/login` endpoint to fall back on.
- **Do not point at port 443.** On a sidecar-exposed Calibre stack, 443 is
  usually the *desktop GUI* (a Selkies/VNC web wrapper with `nginx` in front);
  its `/ajax/*` 404s. The content server is the other listener — see
  **Configuration**.
- **Counting with `wc -l` overstates the library.** `calibredb list` wraps long
  titles onto extra lines, so a non-empty-line count can be ~1.7× the real number.
  Use `scripts/calibre.sh count`, which counts ids.
- **`calibredb search` prints ids**, not titles — pipe through `show` or use
  `list --search <query>` for a table.
- **Anonymous reads may be allowed.** A server with auth enabled still answers
  `401` without credentials, but a server with anonymous access enabled answers
  reads fine and only refuses writes (`403 Anonymous users are not allowed to
  changes`). A read "working" therefore does not prove the credential is valid —
  prove it with a write-capability probe instead
  ([`patterns/authenticate.md`](patterns/authenticate.md)).
- **A `200` from `/cdb/cmd/*` is not success.** Argument errors come back as
  HTTP 200 with `{"err": …}` in the body.
- **Version skew is tolerable for these verbs.** A 6.x `calibredb` drives a 9.x
  content server for list/add/remove/metadata; newer commands may not exist on an
  older client.
- `--password` puts the value in the child's argv briefly. Never enable `set -x`
  or shell tracing around these calls.

## Safety

Read verbs are safe. **Write verbs require `--yes`, and require `--library`** —
the script refuses without both (exit 3). `remove` deletes the book's records
*and its format files from disk*, with no trash and no undo; `remove-format`
deletes a single file; `set-metadata` rewrites database fields. Pass `--yes`
only after the user approved the specific change, and show the before/after
(`show <id>`) rather than chaining bulk edits.
