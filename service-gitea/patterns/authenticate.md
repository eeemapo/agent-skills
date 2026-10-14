# Authenticating to Gitea

## Header

Send the token in an `Authorization: token <TOKEN>` header (OAuth2 style). Gitea
also accepts the token as the password in HTTP basic auth, which is handy for
one-off `curl -u user:token` calls, but the header form is what `scripts/gitea.sh`
uses.

    curl -sS -H "Authorization: token $GITEA_TOKEN" "$GITEA_URL/api/v1/user"

## Verify

`scripts/gitea.sh whoami` prints the login. An empty result or a 401 means the
token is missing, expired, or revoked.

## Scopes

Gitea tokens carry explicit scopes, and **the required scope depends on the
action — not just the resource**:

| Action | Required scope |
|--------|----------------|
| read user/repos | `read:user` |
| read repositories | `read:repository` |
| push/write to a repository | `write:repository` |
| **create / delete a repository** | **`write:user`** |
| read issues/PRs | `read:issue` |
| open/close/comment on issues | `write:issue` |
| packages (container registry) | `read:package` / `write:package` |

A token minted only with `write:repository` **cannot create a repo** — the API
returns `403` with `required=[write:user]`. If a write fails with 403, read the
`required=[...]` list in the response body before touching anything else.

## Minting a token (admin)

With an admin token (or `username:password` basic auth):

    curl -sS -u "$USER:$ADMIN_TOKEN" -X POST -H 'Content-Type: application/json' \
      -d '{"name":"agent","scopes":["read:user","write:user","read:repository","write:repository","read:issue","write:issue"]}' \
      "$GITEA_URL/api/v1/users/$USER/tokens"

The response's `sha1` field is the only time the token is shown — store it
immediately and never echo it.
