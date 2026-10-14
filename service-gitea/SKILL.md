---
name: service-gitea
description: Operate a Gitea server over its REST API — authenticate with a token, list repositories, issues, pull requests, branches, releases, and Actions runs, read files, and (behind an explicit approval gate) create or delete repositories, open/close issues, and comment. Use when working with a Gitea instance, when the user asks what repositories/issues exist, when checking CI runs, or when a change must be made through Gitea's API. Covers the token header, the scope required per action (notably write:user to create a repo), and the --yes write gate.
license: MIT
compatibility: Client-agnostic. Requires network access to a Gitea instance and a token supplied via environment variables. Uses curl and jq.
metadata:
  version: "1.0"
  spec: Agent Skills 1.0
  upstream: Gitea REST API (v1)
---

# Gitea Contract

Gitea exposes a REST API under `/api/v1`. This contract covers the verbs an agent
needs most; the wire-level catalog is in
[`references/rest-api.md`](references/rest-api.md) and the deterministic work is
in [`scripts/gitea.sh`](scripts/gitea.sh).

## How to use this skill

1. Supply configuration from the environment (see **Configuration**). The
   credential source is out of scope — wherever the token lives, resolve it into
   `GITEA_TOKEN` **without echoing it**.
2. Run a verb as a program (do **not** `source` it):
   `bash <skill-dir>/scripts/gitea.sh <verb> [args]`
   (absolute path — a bare `scripts/` path fails as “not found”, which is a
   **path** problem, not an authentication failure).
3. If a verb fails, read **Gotchas** before changing anything.

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| Auth / 401 / 403 / scopes | [`patterns/authenticate.md`](patterns/authenticate.md) | Token header and the scope-per-action table |
| Listing or reading repos, issues, PRs, CI | [`patterns/read-repos.md`](patterns/read-repos.md) | Read endpoints and output shape |
| Creating/deleting repos, opening/closing issues | [`patterns/write-actions.md`](patterns/write-actions.md) | Write verbs and the `--yes` gate |
| Exact endpoints, params, error shapes | [`references/rest-api.md`](references/rest-api.md) | Wire-level catalog |

## Verbs

    scripts/gitea.sh --help
    # read (safe)
    scripts/gitea.sh version                     # server version
    scripts/gitea.sh whoami                      # authenticated login
    scripts/gitea.sh repos                       # your repositories
    scripts/gitea.sh repo <owner/repo>           # one repository
    scripts/gitea.sh issues <owner/repo> [state] # issues (open|closed|all)
    scripts/gitea.sh pulls <owner/repo> [state]  # pull requests
    scripts/gitea.sh branches <owner/repo>       # branches
    scripts/gitea.sh releases <owner/repo>       # releases
    scripts/gitea.sh runs <owner/repo>           # recent Actions runs
    scripts/gitea.sh file <owner/repo> <path> [ref]
    scripts/gitea.sh search <query>
    # write (require --yes)
    scripts/gitea.sh repo-create <name> [--private] [--description D] --yes
    scripts/gitea.sh repo-delete <owner/repo> --yes
    scripts/gitea.sh issue-create <owner/repo> --title T [--body B] --yes
    scripts/gitea.sh issue-close <owner/repo> <index> --yes
    scripts/gitea.sh issue-comment <owner/repo> <index> --body B --yes

## Configuration

| Variable | Required | Meaning |
|----------|----------|---------|
| `GITEA_URL` | yes | Base URL, e.g. `https://gitea.example.invalid` (no trailing `/api`) |
| `GITEA_TOKEN` | yes | Gitea API token |

`GITEA_URL` is **not** a credential and is **not** a field in the vault item — take
it from the task or the host inventory. Resolve only the token from the vault.

Reads are safe by default. **Writes refuse to run without `--yes`** — that is an
explicit approval token, not a formality; pass it only once the user has approved
the specific change.

## Gotchas

- **Scope is per action, and the odd one is repo creation.** A token needs
  `read:repository` / `write:repository` for repos, `read:issue` / `write:issue`
  for issues, but **`write:user` to create or delete a repository**. A missing
  scope returns **HTTP 403** with `required=[...]` in the body — read that before
  assuming the token is wrong.
- **PRs come back from the issues endpoint.** `issues` filters them out with
  `select(.pull_request == null)` so the two verbs stay separate.
- **Lists are capped** at `limit=50` (20 for search/releases/runs). Narrow with a
  query rather than expecting everything.
- **`file` defaults to `ref=main`.** Pass the ref explicitly for other branches.
- Delete verbs are irreversible at the API level; verify the target first.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | success |
| 1 | missing/invalid configuration or an HTTP error |
| 2 | unknown verb (usage printed) |
| 3 | a write verb was called without `--yes` |
