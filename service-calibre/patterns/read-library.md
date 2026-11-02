# Read a Calibre library

All reads default to the server's default library; pass `--library <id>` to read
another. Library ids come from `scripts/calibre.sh libraries`:

    {"library_map": {"import": "import", "fiction": "fiction", …},
     "default_library": "import"}

## Common reads

    scripts/calibre.sh libraries                       # ids + default
    scripts/calibre.sh count --library import          # how many books
    scripts/calibre.sh list --fields title,authors
    scripts/calibre.sh list --search 'tags:unread'
    scripts/calibre.sh list --for-machine --fields id,title,authors
    scripts/calibre.sh search 'author:"Some Author"'   # prints ids
    scripts/calibre.sh show <id>                       # full metadata
    scripts/calibre.sh categories                      # category/value counts
    scripts/calibre.sh raw custom_columns              # custom columns
    scripts/calibre.sh raw export 12 --to-dir /tmp/x   # export one book
    scripts/calibre.sh raw fts_search "quantum"        # full-text search

Anything not wrapped above is reachable through `raw`: everything after the
command is passed to `calibredb` verbatim, so script options must precede it.

`--search` and `search` take calibre's own search expression language
(`tags:`, `author:`, `title:`, `format:`, `pubdate:`, boolean `and/or/not`).

## Reading a record

`show <id>` prints one field per line as `Label : value`. For authors and
titles the **bracketed** value is the sort key, not a second value:

    Author(s) : Elliott Mendelson [Mendelson, Elliott]
    Title     : The C Programming Language, 2nd Edition [C Programming Language..., The]

The bracket is `author_sort` / `sort`. Never read it as an extra author or an
alternative title — and after changing `authors` or `title`, check the bracket
separately, because it does not recompute.

## Traps

- **Count ids, not lines.** `calibredb list` wraps long titles onto additional
  lines, so `| wc -l` or a non-empty-line count reports far more books than exist
  (observed: 217 lines for 125 books). `scripts/calibre.sh count` is id-based: it
  reads `--for-machine` JSON and measures the array, so wrapping cannot affect it.
- **`list` returns the whole library.** There is no default cap, so on a large
  library a `--search` expression is far cheaper than dumping everything.
- **`search` returns ids**, not rows. Use `list --search …` for a table, or feed
  the ids to `show`.
- **The table is column-wrapped for a terminal.** Long values wrap onto extra
  lines that carry no id, so splitting on runs of spaces invents rows with an
  empty id — the same bug that makes `wc -l` wrong. For machine-readable output
  use `--for-machine`, which emits JSON and turns wrapping off:
  `list --for-machine --fields id,title,authors`. (`calibredb` accepts the same
  flag on other verbs; `/cdb/cmd/list` is the fallback —
  `../references/cdb-api.md`.) Valid field names are discovered, not remembered:
  see [`discover-fields.md`](discover-fields.md).
- **Book content** is downloadable: OPDS feeds under `/opds`, or
  `calibredb export` for a batch. Both require the credential when auth is on.

## Not exposed here

Server-side library administration (creating a library, changing its path,
reordering libraries) is not reachable through the content server API; it is a
GUI/CLI operation inside the container.
