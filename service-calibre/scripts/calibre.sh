#!/usr/bin/env bash
# Calibre content-server verbs — calibredb over HTTP, plus raw /ajax endpoints.
# Configuration comes from the environment; credential values are never echoed.
# Read verbs are safe. Write verbs require --yes AND an explicit --library.
# usage: calibre.sh <verb> [options] [args]
set -euo pipefail

: "${CALIBRE_URL:?set CALIBRE_URL (base URL incl. scheme, no trailing slash; resolve it from the stack config ts/ts-serve.json)}"
: "${CALIBRE_USER:?set CALIBRE_USER}"
: "${CALIBRE_PASSWORD:?set CALIBRE_PASSWORD}"
CALIBRE_URL="${CALIBRE_URL%/}"

command -v calibredb >/dev/null 2>&1 || { echo "error: calibredb not on PATH (install the calibre package)" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "error: curl not on PATH" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: calibre.sh <verb> [options] [args]
  read (safe):
    auth                        verify the credential
    libraries                   library ids and the server default (JSON)
    list                        table of books (--search, --limit, --fields)
    search <query>              matching book ids (calibre search expression)
    show <id>                   full metadata for one book
    count                       number of books (id-based; wrapped titles lie)
    categories                  category/value counts for the library
  write (require --yes, and --library):
    add <file>                  upload a book
    remove <id> [<id>...]       DELETE records AND their files (irreversible)
    set-metadata <id> --field <name:value> [--field ...]
    add-format <id> <file>      add or replace one format of an existing book
    remove-format <id> <ext>    delete one format file (e.g. EPUB)
  options:
    -l, --library <id>    library id (reads default to the server default)
    --limit <n>           rows for list (default 20)
    --search <query>      calibre search expression for list
    --fields <list>       comma-separated fields for list
    --field <name:value>  metadata field for set-metadata (repeatable)
    --yes                 confirm a write verb
EOF
}

digest() { curl -sS --digest -u "$CALIBRE_USER:$CALIBRE_PASSWORD" "$@"; }

default_lib() {
  digest "$CALIBRE_URL/ajax/library-info" | jq -r '.default_library // empty'
}

lib_run() { # lib_run <library> <calibredb args...>
  local l="$1"; shift
  calibredb --with-library "$CALIBRE_URL/#$l" \
    --username "$CALIBRE_USER" --password "$CALIBRE_PASSWORD" "$@"
}

need_yes() {
  [ "$yes" = "1" ] || {
    echo "refusing: '$verb' is a write verb; re-run with --yes after explicit user approval" >&2
    exit 3
  }
}

need_lib() {
  [ -n "$lib" ] || {
    echo "refusing: '$verb' is a write verb; name the target library with --library <id>" >&2
    exit 3
  }
}

read_lib() {
  if [ -n "$lib" ]; then printf '%s' "$lib"; else default_lib; fi
}

lib=""; limit=20; searchq=""; fields=""; yes=0; verb=""
field_args=(); pos=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    -l|--library) lib="${2:?--library needs a value}"; shift 2;;
    --limit) limit="${2:?--limit needs a value}"; shift 2;;
    --search) searchq="${2:?--search needs a value}"; shift 2;;
    --fields) fields="${2:?--fields needs a value}"; shift 2;;
    --field) field_args+=("${2:?--field needs name:value}"); shift 2;;
    --yes) yes=1; shift;;
    -*) echo "error: unknown option: $1" >&2; usage; exit 2;;
    *) if [ -z "$verb" ]; then verb="$1"; else pos+=("$1"); fi; shift;;
  esac
done

[ -n "$verb" ] || { usage; exit 2; }

case "$verb" in
  auth)
    l=$(read_lib)
    if [ -z "$l" ]; then echo "error: could not resolve the default library" >&2; exit 1; fi
    if lib_run "$l" list --limit 1 >/dev/null 2>&1; then
      echo "auth ok (library: $l)"
    else
      echo "auth failed: check CALIBRE_USER/CALIBRE_PASSWORD, and that CALIBRE_URL is the CONTENT SERVER (Digest auth, not the GUI port)" >&2
      exit 1
    fi;;

  libraries)
    digest "$CALIBRE_URL/ajax/library-info" | jq .;;

  list)
    l=$(read_lib)
    args=(list --limit "$limit")
    if [ -n "$searchq" ]; then args+=(--search "$searchq"); fi
    if [ -n "$fields" ]; then args+=(--fields "$fields"); fi
    lib_run "$l" "${args[@]}";;

  search)
    [ ${#pos[@]} -ge 1 ] || { echo "search needs <query>" >&2; exit 2; }
    lib_run "$(read_lib)" search "${pos[0]}";;

  show)
    [ ${#pos[@]} -ge 1 ] || { echo "show needs <id>" >&2; exit 2; }
    lib_run "$(read_lib)" show_metadata "${pos[0]}";;

  count)
    l=$(read_lib)
    n=$(lib_run "$l" list --fields id 2>/dev/null | grep -cE '^[0-9]+$' || true)
    printf '%s\n' "${n:-0}";;

  categories)
    lib_run "$(read_lib)" list_categories;;

  add)
    need_yes; need_lib
    [ ${#pos[@]} -ge 1 ] || { echo "add needs <file>" >&2; exit 2; }
    lib_run "$lib" add "${pos[@]}";;

  remove)
    need_yes; need_lib
    [ ${#pos[@]} -ge 1 ] || { echo "remove needs <id> [<id>...]" >&2; exit 2; }
    lib_run "$lib" remove "${pos[@]}";;

  set-metadata)
    need_yes; need_lib
    [ ${#pos[@]} -ge 1 ] || { echo "set-metadata needs <id>" >&2; exit 2; }
    [ ${#field_args[@]} -ge 1 ] || { echo "set-metadata needs at least one --field <name:value>" >&2; exit 2; }
    args=(set_metadata "${pos[0]}")
    for f in "${field_args[@]}"; do args+=(--field "$f"); done
    lib_run "$lib" "${args[@]}";;

  add-format)
    need_yes; need_lib
    [ ${#pos[@]} -ge 2 ] || { echo "add-format needs <id> <file>" >&2; exit 2; }
    lib_run "$lib" add_format "${pos[0]}" "${pos[1]}";;

  remove-format)
    need_yes; need_lib
    [ ${#pos[@]} -ge 2 ] || { echo "remove-format needs <id> <ext>" >&2; exit 2; }
    lib_run "$lib" remove_format "${pos[0]}" "${pos[1]}";;

  *) echo "error: unknown verb: $verb" >&2; usage; exit 2;;
esac
