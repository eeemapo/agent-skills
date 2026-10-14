#!/usr/bin/env bash
# llama-swap control verbs. Reads are safe; unloads require --yes.
# usage: llama-swap.sh <verb> [args]
set -euo pipefail

: "${LLAMA_SWAP_URL:?set LLAMA_SWAP_URL (e.g. https://llama-swap.example.invalid)}"
: "${LLAMA_SWAP_KEY:?set LLAMA_SWAP_KEY (the llama-swap API key)}"
base="${LLAMA_SWAP_URL%/}"
H="Authorization: Bearer $LLAMA_SWAP_KEY"

usage() {
  cat >&2 <<'EOF'
usage: llama-swap.sh <verb> [args]
  read (safe):
    health                 liveness of this swap server
    version                build/version info
    models                 configured models (id, context, capabilities)
    running                currently loaded models and their state
    profiles               configured profiles + which is active
    logs [n]               last n lines of buffered logs (default 50)
  --count  with models|running: print the entry count instead of the list
  write (require --yes):
    unload <model> --yes   unload one running model
    unload-all --yes       unload every running model
EOF
}

die() { echo "error: $*" >&2; exit 1; }
need_yes() { [ "$1" = "1" ] || { echo "refusing: '$2' is a write verb; re-run with --yes after explicit user approval" >&2; exit 3; }; }
get() { curl -sS -f -H "$H" "$base/$1"; }
post() { curl -sS -f -X POST -H "$H" "$base/$1"; }

verb="${1:-}"; shift || true
YES=0; MODEL=""; N=50; COUNT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) YES=1 ;;
    --count) COUNT=1 ;;
    *) if [ -z "$MODEL" ]; then MODEL="$1"; else N="$1"; fi ;;
  esac
  shift
done

# --count: counting belongs in the script. A caller that counts the lines of the
# payload, or takes len() of a parsed one, reports the wrong number — confidently.
count_or() { if [ "$COUNT" = "1" ]; then wc -l | tr -d ' '; else cat; fi; }

case "$verb" in
  ""|-h|--help|help) usage; exit 0 ;;
  health)   get health ;;
  version)  get api/version ;;
  models)   get v1/models | jq -r '.data[] | "\(.id)\t\(.context_length // .context_window // "-")\t\([.capabilities // {} | to_entries[] | select(.value==true) | .key] | join(","))"' | count_or ;;
  running)  get running | jq -r '.running[]? | "\(.model)\t\(.state)"' | count_or ;;
  profiles) get api/profiles ;;
  logs)     curl -sS -m 10 -H "$H" "$base/logs" | tail -n "${N:-50}" ;;
  unload)
    need_yes "$YES" unload
    [ -n "$MODEL" ] || die "unload needs a model id (see 'running')"
    post "api/models/unload/$MODEL" >/dev/null && echo "$MODEL unloaded" ;;
  unload-all)
    need_yes "$YES" unload-all
    post "api/models/unload" >/dev/null && echo "all models unloaded" ;;
  *) echo "unknown verb: $verb" >&2; usage; exit 2 ;;
esac
