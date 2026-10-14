# Gitea REST API — wire catalog

Base: `$GITEA_URL/api/v1`. Auth header: `Authorization: token <TOKEN>`.

## Endpoints used by scripts/gitea.sh

| Verb | Method | Path |
|------|--------|------|
| version | GET | `/version` |
| whoami | GET | `/user` |
| repos | GET | `/user/repos?limit=50` |
| repo | GET | `/repos/{owner}/{repo}` |
| issues | GET | `/repos/{owner}/{repo}/issues?state={open,closed,all}&limit=50` |
| pulls | GET | `/repos/{owner}/{repo}/pulls?state=...&limit=50` |
| branches | GET | `/repos/{owner}/{repo}/branches?limit=50` |
| releases | GET | `/repos/{owner}/{repo}/releases?limit=20` |
| runs | GET | `/repos/{owner}/{repo}/actions/tasks?limit=20` |
| file | GET | `/repos/{owner}/{repo}/contents/{path}?ref={ref}` |
| search | GET | `/repos/search?q={query}&limit=20` |
| repo-create | POST | `/user/repos` |
| repo-delete | DELETE | `/repos/{owner}/{repo}` |
| issue-create | POST | `/repos/{owner}/{repo}/issues` |
| issue-close | PATCH | `/repos/{owner}/{repo}/issues/{index}` `{"state":"closed"}` |
| issue-comment | POST | `/repos/{owner}/{repo}/issues/{index}/comments` |

## Error shape

    {"message":"token does not have at least one of required scope(s), required=[write:user], token scope=read:repository","url":".../api/swagger"}

HTTP 403 with `required=[...]` = a scope problem, not a bad token. HTTP 404 on a
repo you can list = wrong `owner/repo` or the repo was deleted.

## Notes

- Issue/PR numbers are per-repository and shared across the two types.
- `file` returns base64 content for files; the script decodes it.
- Server version observed: `28.0.0`.
