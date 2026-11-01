#!/usr/bin/env bash
# Calibre content-server verbs — calibredb over HTTP, plus raw /ajax endpoints.
# Configuration comes from the environment; credential values are never echoed.
# Read verbs are safe. Write verbs require --yes AND an explicit --library.
# raw passes args to calibredb verbatim, keeps the gate, and refuses no_remote commands.
# usage: calibre.sh <verb> [options] [args]
set -euo pipefail

# Environment is validated after argument parsing, so --help works without it.

command -v calibredb >/dev/null 2>&1 || { echo "error: calibredb not on PATH (install the calibre package)" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "error: curl not on PATH" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: calibre.sh <verb> [options] [args]
  read (safe):
    auth [--library L]          probe read access (not credential proof)
    libraries                   library ids and the server default (JSON)
    list                        table of books (--search, --fields, --for-machine)
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
  raw (any other calibredb command; args after it pass through verbatim):
    raw <command> [args...]     refuses the 6 commands that cannot work remotely;
                                write commands still need --yes and --library, and
                                for raw those must come BEFORE the verb
  options:
    -l, --library <id>    library id (reads default to the server default)
    --search <query>      calibre search expression for list
    --fields <list>       comma-separated fields for list
    --for-machine         JSON output for list (no column wrapping)
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

lib=""; searchq=""; fields=""; machine=0; yes=0; verb=""; raw_args=()
field_args=(); pos=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    -l|--library) lib="${2:?--library needs a value}"; shift 2;;
    --search) searchq="${2:?--search needs a value}"; shift 2;;
    --fields) fields="${2:?--fields needs a value}"; shift 2;;
    --for-machine) machine=1; shift;;
    --field) field_args+=("${2:?--field needs name:value}"); shift 2;;
    --yes) yes=1; shift;;
    --limit) echo "error: there is no --limit; 'list' returns the whole library (narrow it with --search)" >&2; exit 2;;
    -*) echo "error: unknown option: $1" >&2; usage; exit 2;;
    *) if [ -z "$verb" ]; then
         verb="$1"; shift
         if [ "$verb" = raw ]; then raw_args=("$@"); break; fi
       else pos+=("$1"); shift; fi;;
  esac
done

[ -n "$verb" ] || { usage; exit 2; }

: "${CALIBRE_URL:?set CALIBRE_URL (content-server base URL incl. scheme, no trailing slash)}"
: "${CALIBRE_USER:?set CALIBRE_USER}"
: "${CALIBRE_PASSWORD:?set CALIBRE_PASSWORD}"
CALIBRE_URL="${CALIBRE_URL%/}"

case "$verb" in
  auth)
    l=$(read_lib)
    if [ -z "$l" ]; then echo "error: could not resolve the default library (pass --library <id>)" >&2; exit 1; fi
    if err=$(lib_run "$l" list --for-machine --fields id 2>&1 >/dev/null); then
      echo "auth ok (library: $l) - reads work; this does NOT prove the credential (see patterns/authenticate.md)"
    else
      case "$err" in
        *"Not Found"*) echo "error: library '$l' not found - check the ids from the 'libraries' verb" >&2; exit 1;;
      esac
      echo "auth failed (library: $l): ${err:-no detail}" >&2
      echo "check CALIBRE_USER/CALIBRE_PASSWORD, and that CALIBRE_URL is the CONTENT SERVER (Digest auth, not the GUI port)" >&2
      exit 1
    fi;;

  libraries)
    digest "$CALIBRE_URL/ajax/library-info" | jq .;;

  list)
    l=$(read_lib)
    args=(list)
    if [ -n "$searchq" ]; then args+=(--search "$searchq"); fi
    if [ -n "$fields" ]; then args+=(--fields "$fields"); fi
    if [ "$machine" = 1 ]; then args+=(--for-machine); fi
    lib_run "$l" "${args[@]}";;

  search)
    [ ${#pos[@]} -ge 1 ] || { echo "search needs <query>" >&2; exit 2; }
    lib_run "$(read_lib)" search "${pos[0]}";;

  show)
    [ ${#pos[@]} -ge 1 ] || { echo "show needs <id>" >&2; exit 2; }
    lib_run "$(read_lib)" show_metadata "${pos[0]}";;

  count)
    l=$(read_lib)
    if [ -z "$l" ]; then echo "error: could not resolve the default library (pass --library <id>)" >&2; exit 1; fi
    if ! out=$(lib_run "$l" list --for-machine --fields id 2>&1); then
      echo "error: count failed for library '$l':" >&2
      printf '%s\n' "$out" >&2
      exit 1
    fi
    if ! n=$(printf '%s\n' "$out" | jq 'length' 2>/dev/null); then
      echo "error: unexpected output from list for library '$l':" >&2
      printf '%s\n' "$out" | head -n 5 >&2
      exit 1
    fi
    printf '%s\n' "$n";;

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

  raw)
    [ ${#raw_args[@]} -ge 1 ] || { echo "raw needs <command> [args...]" >&2; exit 2; }
    cmd="${raw_args[0]}"
    # --library is a PREFIX of calibredb's --library-path, so a misplaced script
    # option silently repoints the command at a local path and returns nothing.
    for a in "${raw_args[@]}"; do
      case "$a" in
        --library|-l|--yes)
          echo "error: script options must come BEFORE 'raw'; after it they go to calibredb, where --library silently means --library-path" >&2
          exit 2;;
      esac
    done
    # calibredb refuses these against a remote library, and the SERVER does not
    # enforce that -- so the refusal has to live here.
    for bad in add_custom_column backup_metadata catalog check_library remove_custom_column restore_database; do
      if [ "$cmd" = "$bad" ]; then
        echo "refusing: '$cmd' is not supported against a remote library (calibredb refuses it too)" >&2
        exit 3
      fi
    done
    case "$cmd" in
      list|search|show_metadata|list_categories|custom_columns|export|clone|fts_search) ;;
      *) verb="$cmd"; need_yes; need_lib;;
    esac
    lib_run "$(read_lib)" "${raw_args[@]}";;

  *) echo "error: unknown verb: $verb" >&2; usage; exit 2;;
esac
