#!/usr/bin/env bash
# Read-only snapshot of the homelab LLM fleet.
#
#   bash scripts/fleet-status.sh            # nodes + LiteLLM (LiteLLM needs LITELLM_KEY)
#   bash scripts/fleet-status.sh --no-litellm
#
# Reads the llama-swap configs over ssh (lax, phx) and, when LITELLM_KEY is set,
# the front door's catalogue from https://ai.armadillo-hops.ts.net.
# Nothing is written; nothing is restarted.
set -uo pipefail

LITELLM_URL="${LITELLM_URL:-https://ai.armadillo-hops.ts.net}"
want_litellm=1
[ "${1:-}" = "--no-litellm" ] && want_litellm=0

say() { printf '%s\n' "$*"; }
hdr() { printf '\n== %s ==\n' "$*"; }

node_models() {  # $1 = host
  local host=$1 cfg=/opt/ai/config/llama-swap/config.yaml
  if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" "test -r $cfg" 2>/dev/null; then
    say "  (cannot read $cfg on $host)"
    return
  fi
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" \
    "grep -oE '^  \"[^\"]+\":' $cfg | tr -d '\" :'" 2>/dev/null | sed 's/^/  /'
  printf '  containers: '
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" \
    "docker ps --filter name=llama-swap --format '{{.Names}}={{.Status}}' | paste -sd' '" 2>/dev/null \
    || printf '(docker unavailable)'
  say ""
}

hdr "nodes"
for h in lax phx; do
  say "$h"
  node_models "$h"
done

if [ "$want_litellm" = 1 ]; then
  hdr "front door ($LITELLM_URL)"
  if [ -z "${LITELLM_KEY:-}" ]; then
    say "  LITELLM_KEY unset — skipping (resolve it from the vault, never echo it)"
  else
    body=$(curl -sf -m 20 "$LITELLM_URL/v1/models" -H "Authorization: Bearer $LITELLM_KEY") || {
      say "  request failed (auth, or the front door is down)"; body=""; }
    if [ -n "$body" ]; then
      printf '%s' "$body" | grep -oE '"id":"[^"]+"' | cut -d'"' -f4 | sort | sed 's/^/  /'
      say "  total: $(printf '%s' "$body" | grep -oE '"id":"[^"]+"' | wc -l)"
    fi
  fi
fi

hdr "reminders"
say "  node config  : /opt/ai/config/llama-swap/config.yaml   (hot reload, ~2 s)"
say "  front door   : mco:/stackData/litellm/config/config.yaml (hot reload, ~1-2 s)"
say "  a model in the catalogue is not proof the backend starts — send one completion"
