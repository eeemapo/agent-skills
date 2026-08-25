#!/usr/bin/env bash
#
# validate-skill.sh — a dependency-free linter for Agent Skills.
#
# Checks conformance to the Agent Skills Specification and prints a
# structured report (human default, or JSON with --json) so an agent can
# instantly see what passed, what warned, and what failed. Exit code is 1
# when any check FAILs (warnings do not fail), matching linter/LSP tooling.
#
# Usage:
#   bash scripts/validate-skill.sh <path>            # skill dir or SKILL.md file
#   bash scripts/validate-skill.sh --json <path>     # machine-readable report
#   bash scripts/validate-skill.sh --help
#
# <path> may be a skill directory (uses <dir>/SKILL.md) or a SKILL.md file.
#
# Exit codes:
#   0  no FAIL checks (or --help / --json with no failures)
#   1  at least one FAIL check, or usage error

MAX_NAME=64
MAX_DESC=1024
MAX_COMPAT=500
MAX_LINES=500
MAX_TOKENS=5000

RESULTS=()          # "section<TAB>status<TAB>label<TAB>message"
CURRENT_SECTION=""
FM_START=-1
FM_END=-1
declare -gA FM=()   # frontmatter key -> value
FM_LINES=()         # raw frontmatter lines (for YAML colon check)

# --- reporting helpers -----------------------------------------------------

section() { CURRENT_SECTION="$1"; }

add_check() { # add_check <status> <label> [message]
    RESULTS+=("${CURRENT_SECTION}"$'\t'"$1"$'\t'"$2"$'\t'"${3:-}")
}
ok()   { add_check "PASS" "$1" "${2:-}"; }
warn() { add_check "WARN" "$1" "${2:-}"; }
fail() { add_check "FAIL" "$1" "${2:-}"; }

# --- frontmatter parsing ---------------------------------------------------

strip_quotes() { # strip one surrounding pair of quotes
    local v="$1" sq="'"
    if [[ "$v" == \"*\" || "$v" == "${sq}"* ]]; then
        v="${v:1:${#v}-2}"
    fi
    printf '%s' "$v"
}

parse_frontmatter() { # parse <file> -> populates FM, FM_START, FM_END, FM_LINES
    local file="$1"
    local -a lines=()
    mapfile -t lines < "$file"
    local start=-1 end=-1 i
    for i in "${!lines[@]}"; do
        if [[ "${lines[$i]}" == "---" && $start -eq -1 ]]; then
            start=$i
        elif [[ "${lines[$i]}" == "---" && $start -ne -1 && $end -eq -1 ]]; then
            end=$i; break
        fi
    done
    FM_START=$start; FM_END=$end; FM_LINES=()
    if [[ $start -ge 0 && $end -gt $start ]]; then
        for ((i = start + 1; i < end; i++)); do
            local line="${lines[$i]}"
            FM_LINES+=("$line")
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            if [[ "$line" =~ ^[a-zA-Z-]+[[:space:]]*: ]]; then
                local key val
                key="${line%%:*}"; key="${key//[[:space:]]/}"
                val="${line#*:}";  val="${val#"${val%%[![:space:]]*}"}"   # left-trim
                FM["$key"]="$(strip_quotes "$val")"
            fi
        done
    fi
}

# --- checks ----------------------------------------------------------------

run_checks() { # run_checks <skill_file> <skill_dir>
    local file="$1" skill_dir="$2"

    # STRUCTURE
    section "Structure"
    if [[ -f "$file" ]]; then
        ok "SKILL.md present"
    else
        fail "SKILL.md present" "expected at $file"
    fi
    if [[ $FM_START -ge 0 && $FM_END -gt $FM_START ]]; then
        ok "Frontmatter delimited" "-- opening and closing '---' found"
    else
        fail "Frontmatter delimited" "missing or malformed YAML frontmatter (--- ... ---)"
    fi

    # NAME
    section "Name"
    local name="${FM[name]:-}"
    if [[ -z "$name" ]]; then
        fail "name present"
    else
        ok "name present"
        (( ${#name} > MAX_NAME )) && fail "name length <= $MAX_NAME" "found ${#name}"
        [[ "$name" != "${name,,}" ]] && fail "name lowercase"
        [[ "$name" == -* || "$name" == *- ]] && fail "name no leading/trailing hyphen"
        [[ "$name" == *"--"* ]] && fail "name no consecutive hyphens"
        [[ ! "$name" =~ ^[a-z0-9-]+$ ]] && fail "name charset [a-z0-9-]"
        [[ "$dir_name_from" != "$name" ]] && fail "name matches directory" "dir='$dir_name_from' name='$name'"
    fi

    # DESCRIPTION
    section "Description"
    local desc="${FM[description]:-}"
    if [[ -z "$desc" ]]; then
        fail "description present"
    else
        ok "description present" "length ${#desc}"
        (( ${#desc} > MAX_DESC )) && fail "description length <= $MAX_DESC" "found ${#desc}"
    fi

    # OPTIONAL FIELDS
    section "Optional Fields"
    local compat="${FM[compatibility]:-}"
    if [[ -n "$compat" ]]; then
        (( ${#compat} > MAX_COMPAT )) && warn "compatibility length <= $MAX_COMPAT" "found ${#compat}" \
            || ok "compatibility length" "length ${#compat}"
    else
        ok "compatibility" "not set"
    fi
    local lic="${FM[license]:-}"
    if [[ -n "$lic" ]]; then
        if [[ "$lic" == */* ]]; then
            if [[ -f "$skill_dir/$lic" ]]; then ok "license references bundled file" "$lic"; else warn "license references bundled file" "$lic not found"; fi
        else
            ok "license" "$lic"
        fi
    fi
    local at="${FM[allowed-tools]:-}"
    if [[ -n "$at" ]]; then
        if [[ "$at" == *,* || "$at" =~ [[:space:]]{2,} ]]; then
            warn "allowed-tools space-separated" "$at"
        else
            ok "allowed-tools space-separated"
        fi
    fi

    # BODY
    section "Body"
    local -a body_lines=() chars=0 line tokens
    mapfile -t body_lines < "$file"
    for line in "${body_lines[@]}"; do chars=$(( chars + ${#line} )); done
    tokens=$(( (chars + 3) / 4 ))   # rough char->token estimate
    (( ${#body_lines[@]} > MAX_LINES )) && warn "SKILL.md < $MAX_LINES lines" "found ${#body_lines[@]}" \
        || ok "SKILL.md line count" "${#body_lines[@]} lines"
    (( tokens > MAX_TOKENS )) && warn "SKILL.md < $MAX_TOKENS tokens (est.)" "~${tokens} tokens" \
        || ok "SKILL.md token estimate" "~${tokens} tokens"

    # REFERENCES (markdown links resolved against the skill dir)
    section "References"
    local -a links=()
    mapfile -t links < <(grep -oE '\]\([^?#)]*\)' "$file" | sed -E 's/^\]\((.*)\)$/\1/')
    local link path rel rest depth found=0 sq="'"
    for link in "${links[@]}"; do
        [[ -z "$link" ]] && continue
        path="${link%%\?*}"; path="${path%%\#*}"; path="${path#./}"
        [[ "$path" == http:* || "$path" == *://* || "$path" == mailto:* || "$path" == data:* || "$path" == \#* ]] && continue
        rest="${path//[!\/]/}"            # keep only slashes
        depth=$(( ${#rest} + 1 ))         # component count (dir + file)
        if [[ "$path" == *"*"* ]]; then
            if [[ -d "$skill_dir/$path" ]]; then ok "reference $path" "directory exists"; else warn "reference $path" "directory not found"; fi
            found=1; continue
        fi
        if [[ -f "$skill_dir/$path" ]]; then
            (( depth <= 2 )) && ok "reference $path" "exists, one level deep" \
                || warn "reference $path" "exists but ${depth} components (prefer one level deep)"
        else
            warn "reference $path" "file not found"
        fi
        found=1
    done
    (( found == 0 )) && ok "References" "no in-skill markdown links to resolve"

    # YAML (unquoted ': ' or trailing ':' on top-level scalars)
    section "YAML"
    local idx cv firstv ycount=0
    for idx in "${!FM_LINES[@]}"; do
        local l="${FM_LINES[$idx]}"
        [[ -z "${l//[[:space:]]/}" ]] && continue
        [[ "$l" =~ ^[[:space:]]*# ]] && continue
        [[ "$l" != *:* ]] && continue
        firstv="${l:0:1}"
        [[ "$firstv" == " " || "$firstv" == $'\t' ]] && continue      # nested key
        cv="${l#*:}"; cv="${cv#"${cv%%[![:space:]]*}"}"               # left-trim value
        [[ -z "$cv" ]] && continue
        [[ "$cv" == \"*\" || "$cv" == "${sq}"* ]] && continue          # quoted is safe
        if [[ "$cv" == *": "* || "$cv" == *: ]]; then
            warn "unquoted ': '/trailing ':'" "line $(( FM_START + idx + 2 )) -- ${l}"
            (( ycount++ ))
        fi
    done
    (( ycount == 0 )) && ok "YAML unquoted colon" "no ambiguous scalars" \
        || warn "YAML unquoted colon" "${ycount} ambiguous scalar(s)"
}

# --- rendering -------------------------------------------------------------

compute_counts() {
    PASS=0; WARN=0; FAIL=0
    local e st
    for e in "${RESULTS[@]}"; do
        IFS=$'\t' read -r _s st _l _m <<< "$e"
        case "$st" in
            PASS) PASS=$(( PASS + 1 )) ;;
            WARN) WARN=$(( WARN + 1 )) ;;
            FAIL) FAIL=$(( FAIL + 1 )) ;;
        esac
    done
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    printf '%s' "$s"
}

# Emit a JSON string literal (with surrounding double quotes).
jstr() { printf '"%s"' "$(json_escape "$1")"; }

render_human() {
    local cur="" e sec status label msg
    for e in "${RESULTS[@]}"; do
        IFS=$'\t' read -r sec status label msg <<< "$e"
        [[ "$cur" != "$sec" ]] && { printf '\n== %s ==\n' "$sec"; cur="$sec"; }
        printf '  [%-4s] %s' "$status" "$label"
        [[ -n "$msg" ]] && printf ' -- %s\n' "$msg" || printf '\n'
    done
    printf '\n========================================\n'
    printf 'Summary: %d passed, %d warning(s), %d failure(s)\n' "$PASS" "$WARN" "$FAIL"
    (( FAIL > 0 )) && printf 'Result: INVALID\n' || printf 'Result: VALID\n'
}

render_json() {
    local valid="true" e sec status label msg first=1
    (( FAIL > 0 )) && valid="false"
    printf '{\n'
    printf '  "skill": %s,\n' "$(jstr "$dir_name_from")"
    printf '  "file": %s,\n' "$(jstr "$skill_file")"
    printf '  "valid": %s,\n' "$valid"
    printf '  "summary": {"total": %d, "pass": %d, "warn": %d, "fail": %d},\n' \
        "$(( PASS + WARN + FAIL ))" "$PASS" "$WARN" "$FAIL"
    printf '  "checks": [\n'
    for e in "${RESULTS[@]}"; do
        IFS=$'\t' read -r sec status label msg <<< "$e"
        (( first )) && first=0 || printf ',\n'
        printf '    {"section": %s, "status": %s, "label": %s, "message": %s}\n' \
            "$(jstr "$sec")" "$(jstr "$status")" "$(jstr "$label")" "$(jstr "$msg")"
    done
    printf '  ]\n'
    printf '}\n'
}

# --- main ------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage: validate-skill.sh [--json] <path>

Linter for Agent Skills. Checks conformance to the Agent Skills
Specification and prints a structured report. <path> may be a skill
directory (uses <dir>/SKILL.md) or a SKILL.md file.

Checks: name format/length/lowercase/hyphens/dir-match, description
length, compatibility length, license file, allowed-tools, body line
count and token estimate, markdown references (existence + one level
deep), and YAML unquoted-colon validity.

Options:
  --json      Emit a machine-readable JSON report
  --help      Show this help

Exit codes: 0 = no failures, 1 = one or more failures / usage error.
EOF
}

main() {
    local json=0
    [[ "${1:-}" == "--json" ]] && { json=1; shift; }
    if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage; exit 0
    fi

    local target="$1" skill_file
    if [[ -d "$target" ]]; then skill_file="$target/SKILL.md"
    elif [[ -f "$target" ]]; then skill_file="$target"
    else echo "ERROR: SKILL.md not found at '$target'"; exit 1; fi

    if [[ -d "$target" ]]; then dir_name_from="$(basename "$target")"
    else dir_name_from="$(basename "$(dirname "$skill_file")")"; fi

    parse_frontmatter "$skill_file"
    run_checks "$skill_file" "$(dirname "$skill_file")"
    compute_counts

    (( json )) && render_json || render_human
    (( FAIL > 0 )) && exit 1 || exit 0
}

main "$@"
