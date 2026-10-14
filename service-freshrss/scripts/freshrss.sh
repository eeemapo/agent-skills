#!/usr/bin/env bash
# FreshRSS Google Reader API verbs.
# Configuration from the environment; secrets are never echoed.
# Read verbs are safe. Write verbs require --yes (explicit user approval).
# usage: freshrss.sh <verb> [args]
set -euo pipefail

: "${FRESHRSS_BASE_URL:?set FRESHRSS_BASE_URL (e.g. https://freshrss.example.invalid)}"
api="${FRESHRSS_BASE_URL%/}/api/greader.php"

get_token() {
  : "${FRESHRSS_USER:?set FRESHRSS_USER}"
  : "${FRESHRSS_API_PASSWORD:?set FRESHRSS_API_PASSWORD (the API password, not the login password)}"
  local resp
  if ! resp=$(curl -sS -f -X POST \
        --data-urlencode "Email=$FRESHRSS_USER" \
        --data-urlencode "Passwd=$FRESHRSS_API_PASSWORD" \
        "$api/accounts/ClientLogin" 2>/dev/null); then
    echo "auth failed: check FRESHRSS_USER and FRESHRSS_API_PASSWORD (API password, not login password)" >&2
    return 1
  fi
  printf '%s\n' "$resp" | sed -n 's/^Auth=//p'
}

call() { # GET (read)
  local t; t=$(get_token) || exit 1
  [ -n "$t" ] || { echo "auth failed: no Auth token" >&2; exit 1; }
  curl -sS -f -H "Authorization: GoogleLogin auth=$t" "$api/$1"
}

emit() { # emit <path> <jq-key> — full JSON, or just the entry count with --count
  local path="$1" key="$2"
  if [ "$count" = "1" ]; then
    call "$path" | jq -r ".$key | length"
  else
    call "$path"
  fi
}

post() { # POST (write); adds the per-session action token as T=
  local path="$1"; shift
  local t at; t=$(get_token) || exit 1
  [ -n "$t" ] || { echo "auth failed: no Auth token" >&2; exit 1; }
  if ! at=$(curl -sS -f -H "Authorization: GoogleLogin auth=$t" "$api/reader/api/0/token" 2>/dev/null); then
    echo "could not fetch action token" >&2; exit 1
  fi
  curl -sS -f -X POST -H "Authorization: GoogleLogin auth=$t" --data-urlencode "T=$at" "$@" "$api/$path"
}

need_yes() { # need_yes <yesflag> <verb>
  [ "$1" = "1" ] || { echo "refusing: '$2' is a write verb; re-run with --yes after explicit user approval" >&2; exit 3; }
}

usage() {
  cat >&2 <<'EOF'
usage: freshrss.sh <verb> [args]
  read (safe):
    auth | whoami | subscriptions | tags
    stream [streamId] [n]
    item <itemId>
  --count  with subscriptions|tags|stream: print the number of entries, not JSON
  write (require --yes):
    mark-read <itemId> --yes | mark-unread <itemId> --yes
    star <itemId> --yes | unstar <itemId> --yes
    subscribe <feedUrl> [--title T] --yes | unsubscribe <streamId|feedUrl> --yes
    mark-all-read <streamId> --yes
EOF
}

[ $# -ge 1 ] || { usage; exit 2; }
verb="$1"; shift

# --count: list verbs print the entry count instead of the payload. Counting
# belongs here, not in the caller: the payload is an object, so a caller that
# parses it and takes len() gets the number of KEYS (1), not the number of feeds.
count=0
args=()
for a in "$@"; do
  case "$a" in
    --count) count=1;;
    *) args+=("$a");;
  esac
done
set -- ${args[@]+"${args[@]}"}

case "$verb" in
  -h|--help) usage; exit 0;;
  auth) get_token >/dev/null || exit 1; echo "auth ok (token acquired)";;
  whoami) call "reader/api/0/user-info";;
  subscriptions) emit "reader/api/0/subscription/list?output=json" subscriptions;;
  tags) emit "reader/api/0/tag/list?output=json" tags;;
  stream)
    sid="${1:-user/-/state/com.google/reading-list}"; n="${2:-20}"
    enc=$(printf '%s' "$sid" | sed 's|/|%2F|g')
    emit "reader/api/0/stream/contents/$enc?output=json&n=$n" items;;
  item)
    [ $# -ge 1 ] || { echo "item needs <itemId>" >&2; exit 2; }
    t=$(get_token) || exit 1
    curl -sS -f -X POST -H "Authorization: GoogleLogin auth=$t" \
      --data-urlencode "i=$1" --data-urlencode "output=json" \
      "$api/reader/api/0/stream/items/contents";;
  mark-read|mark-unread|star|unstar)
    item=""; yes=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --yes) yes=1; shift;;
        -*) echo "unknown flag: $1" >&2; exit 2;;
        *) [ -z "$item" ] || { echo "extra arg: $1" >&2; exit 2; }; item="$1"; shift;;
      esac
    done
    [ -n "$item" ] || { echo "$verb needs <itemId>" >&2; exit 2; }
    need_yes "$yes" "$verb"
    case "$verb" in
      mark-read)   op=a; tg=read;;
      mark-unread) op=r; tg=read;;
      star)        op=a; tg=starred;;
      unstar)      op=r; tg=starred;;
    esac
    post "reader/api/0/edit-tag" --data-urlencode "$op=user/-/state/com.google/$tg" --data-urlencode "i=$item"; echo;;
  subscribe|unsubscribe)
    feed=""; title=""; yes=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --yes) yes=1; shift;;
        --title) title="${2:?}"; shift 2;;
        -*) echo "unknown flag: $1" >&2; exit 2;;
        *) [ -z "$feed" ] || { echo "extra arg: $1" >&2; exit 2; }; feed="$1"; shift;;
      esac
    done
    [ -n "$feed" ] || { echo "$verb needs <feedUrl|streamId>" >&2; exit 2; }
    need_yes "$yes" "$verb"
    case "$verb" in subscribe) ac=subscribe;; unsubscribe) ac=unsubscribe;; esac
    sid="$feed"; case "$sid" in feed/*) ;; *) sid="feed/$sid";; esac
    if [ -n "$title" ]; then
      post "reader/api/0/subscription/edit" --data-urlencode "ac=$ac" --data-urlencode "s=$sid" --data-urlencode "t=$title"
    else
      post "reader/api/0/subscription/edit" --data-urlencode "ac=$ac" --data-urlencode "s=$sid"
    fi
    echo;;
  mark-all-read)
    sid=""; yes=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --yes) yes=1; shift;;
        -*) echo "unknown flag: $1" >&2; exit 2;;
        *) [ -z "$sid" ] || { echo "extra arg: $1" >&2; exit 2; }; sid="$1"; shift;;
      esac
    done
    [ -n "$sid" ] || { echo "mark-all-read needs <streamId>" >&2; exit 2; }
    need_yes "$yes" "$verb"
    post "reader/api/0/mark-all-as-read" --data-urlencode "s=$sid"; echo;;
  *) echo "error: unknown verb: $verb" >&2; usage; exit 2;;
esac
