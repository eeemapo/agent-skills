# Discover the valid fields

Field names differ per calibre version and per library (custom columns), so do
not work from a remembered list. Ask the client, then ask the library.

## Builtin fields

The client prints the fields it accepts, so this tracks the installed version:

    calibredb list --help | awk '/Available fields:/{f=1} f&&/Default:/{exit} f'

`id` is always available even though that list omits it.

## Custom columns (per library)

    scripts/calibre.sh --library <id> raw custom_columns

Empty output means the library defines none. Custom column labels are valid
`--fields` values in that library only.

## Fields a library actually carries

    scripts/calibre.sh list --library <id> --fields all --for-machine | jq -r '.[0] | keys[]'

`all` is a special value that selects every field present in the records, so
this is a *sample of the data*, not the schema — a field with no values in that
library will not appear.

## Validate a candidate

A wrong name is rejected with the offending names, so guessing is cheap to check:

    scripts/calibre.sh list --library <id> --fields <candidate> --for-machine
    # Unknown fields: <candidate>

## Caveats

- `series` is accepted as a `--fields` value, but `list` emits only
  `series_index`; read the series name with `show_metadata <id>`.
- `all` reflects one library's data — re-run it per library.
- Names are case-sensitive and singular. When unsure, validate rather than guess.
