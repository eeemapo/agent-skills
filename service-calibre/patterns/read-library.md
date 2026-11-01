# Read a Calibre library

All reads default to the server's default library; pass `--library <id>` to read
another. Library ids come from `scripts/calibre.sh libraries`:

    {"library_map": {"import": "import", "fiction": "fiction", …},
     "default_library": "import"}

## Common reads

    scripts/calibre.sh libraries                       # ids + default
    scripts/calibre.sh count --library import          # how many books
    scripts/calibre.sh list --limit 20 --fields title,authors
    scripts/calibre.sh list --search 'tags:unread' --limit 50
    scripts/calibre.sh search 'author:"Some Author"'   # prints ids
    scripts/calibre.sh show <id>                       # full metadata
    scripts/calibre.sh categories                      # category/value counts

`--search` and `search` take calibre's own search expression language
(`tags:`, `author:`, `title:`, `format:`, `pubdate:`, boolean `and/or/not`).

## Traps

- **Count ids, not lines.** `calibredb list` wraps long titles onto additional
  lines, so `| wc -l` or a non-empty-line count reports far more books than exist
  (observed: 217 lines for 125 books). `scripts/calibre.sh count` is id-based.
- **`search` returns ids**, not rows. Use `list --search …` for a table, or feed
  the ids to `show`.
- **The table is column-wrapped for a terminal.** For machine-readable output use
  `--fields id,title,authors` and split on runs of spaces, or query the CDB API
  directly with `/cdb/cmd/list` (`../references/cdb-api.md`).
- **Book content** is downloadable: OPDS feeds under `/opds`, or
  `calibredb export` for a batch. Both require the credential when auth is on.

## Not exposed here

Server-side library administration (creating a library, changing its path,
reordering libraries) is not reachable through the content server API; it is a
GUI/CLI operation inside the container.
