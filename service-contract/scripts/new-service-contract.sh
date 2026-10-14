#!/usr/bin/env bash
# Scaffold a new service-contract skill from a generic, environment-free template.
#
# usage: new-service-contract.sh <skill-name> [target-dir]
#
# Creates <target-dir>/<skill-name>/ with a placeholder SKILL.md, a patterns/
# stub, and a scripts/<skill-name>.sh stub. Nothing environment-specific is
# written: every endpoint and credential appears as a placeholder.
set -euo pipefail

name="${1:-}"
target="${2:-.}"

if [[ -z "$name" ]]; then
  echo "usage: $(basename "$0") <skill-name> [target-dir]" >&2
  exit 2
fi

if ! [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "error: name must be lowercase alphanumeric with single hyphens (e.g. my-service)" >&2
  exit 2
fi

dir="$target/$name"
if [[ -e "$dir" ]]; then
  echo "error: $dir already exists" >&2
  exit 1
fi

mkdir -p "$dir/patterns" "$dir/references" "$dir/scripts"

cat > "$dir/SKILL.md" <<'EOF'
---
name: __NAME__
description: Operate <the service> — authenticate to <base-url> and run its verbs. Use when authenticating or acting on <the service>. Replace this with concrete service nouns and verbs for reliable triggering.
license: MIT
compatibility: Client-agnostic. Requires network access to <the service> and a credential supplied via an environment variable.
metadata:
  version: "0.1"
---

# <Service> Contract

<One paragraph on what the service is and what this contract lets an agent do.>

## How to use this skill

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| Authenticating | [patterns/authenticate.md](patterns/authenticate.md) | Auth handshake and failure signals |

Add one pattern file per additional non-trivial workflow.

## Verbs

    scripts/__NAME__.sh --help    # list verbs
    scripts/__NAME__.sh auth      # verify credentials
    scripts/__NAME__.sh read ...  # read state

## Configuration

Resolve everything from the environment; never hardcode.

| Variable | Meaning |
|---|---|
| SERVICE_BASE_URL | Base URL of <the service> |
| SERVICE_TOKEN    | The credential field that actually authenticates |

## Gotchas

- <exact string that looks right but fails> -> <what to use instead>
- Failure signal: <status or error> means <wrong credential versus wrong request>

## Safety

Read verbs are safe. Destructive verbs require an explicit user decision.
EOF

cat > "$dir/patterns/authenticate.md" <<'EOF'
# Authenticate to <the service>

1. Confirm which credential field actually authenticates (not the obvious one).
2. Run the auth verb and inspect the success or failure signal.
3. On failure, distinguish wrong-credential from wrong-request.

<Steps specific to this service.>
EOF

cat > "$dir/scripts/__NAME__.sh" <<'EOF'
#!/usr/bin/env bash
# <service> contract verbs. Configuration from the environment; no secrets echoed.
# usage: __NAME__.sh {auth|read|act} [args]
set -euo pipefail

case "${1:-}" in
  -h|--help|"")
    echo "usage: $(basename "$0") {auth|read|act} [args]" >&2
    exit 0
    ;;
esac

: "${SERVICE_BASE_URL:?set SERVICE_BASE_URL}"
: "${SERVICE_TOKEN:?set SERVICE_TOKEN}"

case "${1:-}" in
  auth)
    # Verify the credential; print status only, never the secret.
    # Replace this with the known-good request for <the service>.
    echo "TODO: implement auth for <the service>" >&2
    exit 3
    ;;
  *)
    echo "error: unknown verb: $1" >&2
    exit 2
    ;;
esac
EOF

sed -i "s/__NAME__/$name/g" "$dir/SKILL.md" "$dir/scripts/__NAME__.sh"
mv "$dir/scripts/__NAME__.sh" "$dir/scripts/$name.sh"
chmod +x "$dir/scripts/$name.sh"

echo "created $dir"
echo "next: fill in the auth request, capture the traps, and evaluate against your weakest target model."
