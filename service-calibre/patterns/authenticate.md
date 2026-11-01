# Authenticate to a Calibre content server

Calibre's content server authenticates with **HTTP Digest** (`realm="calibre"`,
MD5, `qop="auth"`). `calibredb` negotiates it; bare `curl` needs `--digest`.

## Steps

1. Resolve `CALIBRE_URL` from the stack's serve config — the hostname plus the
   port that forwards to the content server's internal **8081** (see
   `../SKILL.md`, *Configuration*). Do not assume 443; that is often the desktop
   GUI listener instead.
2. Resolve `CALIBRE_USER` / `CALIBRE_PASSWORD` from the vault item that holds
   them (`username` / `password`) inside a `vault_run`, so the values only ever
   exist in the child's environment.
3. Run `scripts/calibre.sh auth` — it lists one book through `calibredb` and
   reports `auth ok`.

## Failure signals

| Symptom | Meaning |
|---|---|
| `400 Unsupported authentication method` | You sent **Basic**. Digest is required (`curl --digest`, or use `calibredb`) |
| `401 Unauthorized` on every path, `WWW-Authenticate: Digest …` | The server requires auth and no (valid) credential arrived |
| `403 Anonymous users are not allowed to make changes` | The server resolved you as anonymous; reads may still work |
| `404` from `/ajax/*`, `nginx` in the headers | Wrong port — you are on the GUI wrapper, not the content server |
| `404` from `/ajax/login` | Expected: calibre has no login endpoint; auth is Digest only |
| Connection refused / TLS error | Wrong host or port, or your client is not on the network path to it |

## Proving the credential without mutating anything

Reads can be anonymous, so a working `list` does **not** prove the credential is
valid. Prove it with a write attempt against a book id that cannot exist —
authorization is checked before the lookup, so an authorized user reaches the
lookup and an anonymous one is refused:

    scripts/calibre.sh set-metadata 999999 --field title:probe --library <id> --yes
    # authorized   → exit 1, "No book with id: 999999 in the database"
    # unauthorized → "Forbidden" / 403 anonymous-changes

`remove 999999 --library <id> --yes` discriminates too, but a server with
nothing to remove exits **0 silently** — use `set-metadata` when you want a
positive message. Use an id far above anything in the library, and never probe
with a real id.

## Notes

The credential is a content-server *user*, not an administrator: it can manage
books, but it cannot change server settings, users, ports, or which libraries are
served. Those live in calibre's settings and user database, reachable only
through the GUI or `calibre-server --manage-users` inside the container.
