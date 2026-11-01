# Calibre content-server wire format

## Topology

A Calibre container runs two listeners:

| Internal | What | Typical exposure |
|---|---|---|
| 8080 | desktop GUI, wrapped for the web (Selkies/VNC), `nginx` in front | the stack hostname on **443** |
| 8081 | **content server** (this API) | a separate TLS-terminated TCP port published in `ts/ts-serve.json` |

Published names/ports come from the stack's serve config, e.g.:

    { "TCP": { "443":  { "HTTPS": true },
               "8082": { "TCPForward": "localhost:8081",
                         "TerminateTLS": "<stack-hostname>" } },
      "Web": { "<stack-hostname>:443": { "Handlers": { "/": { "Proxy": "http://127.0.0.1:8080" } } } } }

So `https://<stack-hostname>:8082` is the content server and
`https://<stack-hostname>/` is the GUI — **not** the API. Its `/ajax/*`
endpoints 404 with an `nginx` server header.

## Authentication

HTTP **Digest**, `realm="calibre"`, MD5, `qop="auth"`:

    curl --digest -u "$CALIBRE_USER:$CALIBRE_PASSWORD" <url>

- Basic → `400 {"error": …}` / `Unsupported authentication method`
- No credential → `401` + `WWW-Authenticate: Digest …`
- Anonymous writes → `403 Anonymous users are not allowed to make changes`
- No login endpoint: `/ajax/login` is `404`

## Stable read endpoints

    GET /ajax/library-info
    → {"library_map": {"import": "import", …}, "default_library": "import"}

    GET /opds                 → Atom/OPDS acquisition feed
    GET /opds/…               → nav + category feeds

## Command API (`/cdb/cmd/*`)

Same commands as the `calibredb` CLI. **POST only** (GET → `405`), with the
library in the query string and the arguments as a **positional JSON array**:

    POST /cdb/cmd/<command>?library_id=<lib>
    Content-Type: application/json

Verified example — `list(fields, sort_by, ascending, search_text, limit)`:

    curl --digest -u "$CALIBRE_USER:$CALIBRE_PASSWORD" \
      -X POST -H 'Content-Type: application/json' \
      -d '[["id","title"],"title",true,"",3]' \
      "https://<stack-hostname>:8082/cdb/cmd/list?library_id=import"

    → {"result": {"book_ids": [214, 157, 245],
                  "data": {"title": {"214": "…", "157": "…", "245": "…"}},
                  "metadata": {...}}}

Notes:

- The array maps **by position** onto the command's Python signature, not by
  name. Supplying too few arguments yields
  `{"err": "implementation() missing N required positional arguments: …"}`
  which names the remaining parameters — use it to discover a signature.
- **Argument errors are HTTP 200** with `{"err": …}` in the body. A 200 is not
  success; inspect the body.
- `{"args": […]}` and object bodies (`{"ascending": …}`) are misread as a single
  positional argument — do not use them.
- Hand-rolling these calls is fragile. Prefer `calibredb`, which is the
  reference client for the same endpoint.
