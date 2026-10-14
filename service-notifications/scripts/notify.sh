#!/usr/bin/env bash
# Human-facing notifications: Bark (APNs push) and Apprise (hub).
# These verbs are user-visible side effects (a real person gets pinged) but they
# do not mutate any service state, so they are not gated behind --yes.
# usage: notify.sh <verb> [args]
set -euo pipefail

: "${BARK_URL:?set BARK_URL (e.g. bark.example.invalid or https://bark.example.invalid)}"
: "${BARK_KEY:?set BARK_KEY (the Bark device key)}"
APPRISE_URL="${APPRISE_URL:-}"

# The vault stores these hosts WITHOUT a scheme. Accept either form so that a
# missing "https://" cannot silently become a port-80 connection failure.
case "$BARK_URL" in http://*|https://*) ;; *) BARK_URL="https://$BARK_URL" ;; esac
BARK_URL="${BARK_URL%/}"
case "$APPRISE_URL" in ""|http://*|https://*) ;; *) APPRISE_URL="https://$APPRISE_URL" ;; esac
APPRISE_URL="${APPRISE_URL%/}"

usage() {
  cat >&2 <<'EOF'
usage: notify.sh <verb> [args]
  read (safe):
    ping                              check the Bark server is up
    info                              Bark server version and device count
  send (user-visible):
    bark <title> <body> [--level active|timeSensitive|passive] [--group G]
    apprise <title> <body> [--type info|success|warning|failure]
EOF
}

die() { echo "error: $*" >&2; exit 1; }

verb="${1:-}"; shift || true
TITLE=""; BODY=""; LEVEL="active"; GROUP="pi"; TYPE="info"
pos=()
while [ $# -gt 0 ]; do
  case "$1" in
    --level) LEVEL="${2:-active}"; shift ;;
    --group) GROUP="${2:-pi}"; shift ;;
    --type)  TYPE="${2:-info}"; shift ;;
    *) pos+=("$1") ;;
  esac
  shift
done

json_escape() { printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

case "$verb" in
  ""|-h|--help|help) usage; exit 0 ;;
  ping) curl -sS -f "$BARK_URL/ping" ;;
  info) curl -sS -f "$BARK_URL/info" | jq -r '"bark \(.version) — \(.devices) device(s)"' ;;
  bark)
    TITLE="${pos[0]:?title required}"; BODY="${pos[1]:?body required}"
    curl -sS -f -X POST "$BARK_URL/push" -H 'Content-Type: application/json' \
      -d "{\"device_key\":$(json_escape "$BARK_KEY"),\"title\":$(json_escape "$TITLE"),\"body\":$(json_escape "$BODY"),\"level\":$(json_escape "$LEVEL"),\"group\":$(json_escape "$GROUP")}" \
      | jq -r '.code // .message // "sent"' ;;
  apprise)
    TITLE="${pos[0]:?title required}"; BODY="${pos[1]:?body required}"
    [ -n "$APPRISE_URL" ] || die "apprise needs APPRISE_URL set"
    # Apprise answers with HTTP 200 and a plain-text log; the last line is the result.
    curl -sS -f -X POST "$APPRISE_URL/notify" \
      --data-urlencode "title=$TITLE" --data-urlencode "body=$BODY" --data-urlencode "type=$TYPE" \
      | tail -n 1 ;;
  *) echo "unknown verb: $verb" >&2; usage; exit 2 ;;
esac
