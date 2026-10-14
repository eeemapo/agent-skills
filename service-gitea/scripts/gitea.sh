#!/usr/bin/env bash
# Gitea REST API verbs. Read verbs are safe; write verbs require --yes.
# Configuration comes from the environment; token values are never echoed.
# usage: gitea.sh <verb> [args]   (see --help)
set -euo pipefail

: "${GITEA_URL:?set GITEA_URL (e.g. https://gitea.example.invalid)}"
: "${GITEA_TOKEN:?set GITEA_TOKEN (a Gitea API token)}"
api="${GITEA_URL%/}/api/v1"

usage() {
  cat >&2 <<'EOF'
usage: gitea.sh <verb> [args]
  read (safe):
    version                          server version
    whoami                           the authenticated user
    repos [owner]                    repositories (default: yours)
    repo <owner/repo>                one repository
    issues <owner/repo> [state]      issues (open|closed|all; default open)
    pulls <owner/repo> [state]       pull requests
    branches <owner/repo>            branches
    releases <owner/repo>            releases
    runs <owner/repo>                recent Actions runs
    file <owner/repo> <path> [ref]   file contents (raw)
    search <query>                   search repositories
  write (require --yes):
    repo-create <name> [--private] [--description D] --yes
    repo-delete <owner/repo> --yes
    issue-create <owner/repo> --title T [--body B] --yes
    issue-close <owner/repo> <index> --yes
    issue-comment <owner/repo> <index> --body B --yes
EOF
}

die() { echo "error: $*" >&2; exit 1; }

need_yes() { # need_yes <flag> <verb>
  [ "$1" = "1" ] || { echo "refusing: '$2' is a write verb; re-run with --yes after explicit user approval" >&2; exit 3; }
}

get()  { curl -sS -f -H "Authorization: token $GITEA_TOKEN" "$api/$1"; }
send() { # send <METHOD> <path> <json>
  curl -sS -f -X "$1" -H "Authorization: token $GITEA_TOKEN" \
       -H 'Content-Type: application/json' -d "$3" "$api/$2"
}

# ---- arg parsing: pull --title/--body/--description/--private/--yes ----
verb="${1:-}"; shift || true
YES=0; TITLE=""; BODY=""; DESC=""; PRIVATE=0; positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) YES=1 ;;
    --title) TITLE="${2:-}"; shift ;;
    --body) BODY="${2:-}"; shift ;;
    --description) DESC="${2:-}"; shift ;;
    --private) PRIVATE=1 ;;
    *) positional+=("$1") ;;
  esac
  shift
done

json_escape() { printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

case "$verb" in
  ""|-h|--help|help) usage; exit 0 ;;
  version) get version ;;
  whoami)  get user | jq -r '.login' ;;
  repos)   get "user/repos?limit=50" | jq -r '.[].full_name' ;;
  repo)    get "repos/${positional[0]:?owner/repo required}" | jq -r '"\(.full_name)\t\(.private)\t\(.default_branch)\t\(.size)kb"' ;;
  issues)  get "repos/${positional[0]:?owner/repo required}/issues?state=${positional[1]:-open}&limit=50" \
             | jq -r '.[] | select(.pull_request == null) | "#\(.number)\t\(.state)\t\(.title)"' ;;
  pulls)   get "repos/${positional[0]:?owner/repo required}/pulls?state=${positional[1]:-open}&limit=50" \
             | jq -r '.[] | "#\(.number)\t\(.state)\t\(.title)"' ;;
  branches) get "repos/${positional[0]:?owner/repo required}/branches?limit=50" | jq -r '.[].name' ;;
  releases) get "repos/${positional[0]:?owner/repo required}/releases?limit=20" | jq -r '.[] | "\(.tag_name)\t\(.name // "")"' ;;
  runs)    get "repos/${positional[0]:?owner/repo required}/actions/tasks?limit=20" \
             | jq -r '.workflow_runs[]? | "#\(.run_number)\t\(.status)\t\(.conclusion // "-")\t\(.head_branch)\t\(.display_title)"' ;;
  file)    get "repos/${positional[0]:?owner/repo required}/contents/${positional[1]:?path required}?ref=${positional[2]:-main}" \
             | jq -r '.content' | base64 -d ;;
  search)  get "repos/search?limit=20&q=$(printf '%s' "${positional[0]:?query required}" | jq -sRr @uri)" \
             | jq -r '.data[].full_name' ;;

  repo-create)
    need_yes "$YES" repo-create
    send POST "user/repos" "{\"name\":$(json_escape "${positional[0]:?name required}"),\"private\":$([ $PRIVATE -eq 1 ] && echo true || echo false),\"description\":$(json_escape "$DESC")}" \
      | jq -r '.full_name + " created"' ;;
  repo-delete)
    need_yes "$YES" repo-delete
    curl -sS -f -X DELETE -H "Authorization: token $GITEA_TOKEN" "$api/repos/${positional[0]:?owner/repo required}" >/dev/null \
      && echo "${positional[0]} deleted" ;;
  issue-create)
    need_yes "$YES" issue-create
    send POST "repos/${positional[0]:?owner/repo required}/issues" \
      "{\"title\":$(json_escape "${TITLE:?--title required}"),\"body\":$(json_escape "$BODY")}" \
      | jq -r '"issue #\(.number) opened: \(.html_url)"' ;;
  issue-close)
    need_yes "$YES" issue-close
    send PATCH "repos/${positional[0]:?owner/repo required}/issues/${positional[1]:?index required}" '{"state":"closed"}' \
      | jq -r '"issue #\(.number) is now \(.state)"' ;;
  issue-comment)
    need_yes "$YES" issue-comment
    send POST "repos/${positional[0]:?owner/repo required}/issues/${positional[1]:?index required}/comments" \
      "{\"body\":$(json_escape "${BODY:?--body required}")}" \
      | jq -r '"comment \(.id) added"' ;;

  *) echo "unknown verb: $verb" >&2; usage; exit 2 ;;
esac
