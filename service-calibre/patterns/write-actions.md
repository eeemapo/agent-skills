# Write to a Calibre library

Writes change real books. Every write verb in the script requires **both** a
named `--library` and `--yes`, and refuses otherwise (exit 3) — the gate exists
so a model cannot trigger a mutation by accident or against an unstated library.

## Verbs and their reach

| Verb | Effect | Reversible? |
|---|---|---|
| `add <file>` | upload a book; calibre derives metadata from the file | yes (then `remove`) |
| `add-format <id> <file>` | add or replace one format of an existing book | replace = the old file is gone |
| `set-metadata <id> --field name:value` | rewrite database fields (title, authors, tags, series, custom columns) | only if you captured the old value |
| `remove-format <id> <ext>` | delete one format file, keep the book | **no** |
| `remove <id>…` | delete the record **and every format file on disk** | **no — no trash** |

`calibredb embed_metadata` (rewriting metadata *into* the ebook files) is not
wrapped: it corrupts files when misapplied. Treat it as a manual, single-book
operation after explicit approval.

## How to do it safely

1. `show <id>` first and keep the output — it is your only before-state.
2. Make the smallest change that answers the request; one id, one field.
3. Apply with `--library <id> --yes`.
4. `show <id>` again and diff the result.
5. Never loop over `remove` or `set-metadata` across a search result. If a bulk
   change is genuinely wanted, list the ids, show the user what will change, and
   get approval for the whole set — then still apply it id by id.

## Failure signals

- `Forbidden` / `403 Anonymous users are not allowed to make changes` — the
  server resolved you as anonymous; the credential or the auth scheme is wrong
  (see [`authenticate.md`](authenticate.md)), not the book.
- `No book with id: N in the database` — authorization passed; the id is wrong.
  (`remove` on a missing id prints nothing and exits 0; `set-metadata` is the
  one that reports the lookup failure.)
- `The OPF file … does not exist` — `set_metadata` was called without
  `--field`, so calibredb treated the argument as an OPF path.
