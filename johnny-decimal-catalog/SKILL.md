---
name: johnny-decimal-catalog
description: Operate a Johnny.Decimal system in catalog space — a Markdown/Obsidian vault that indexes everything while bulk data lives outside sync and is only referenced. Use when creating, renaming, filing, or linking JD-numbered notes; auditing a vault for spec compliance; or whenever the user mentions Johnny.Decimal, JD IDs (e.g. 12.34), areas/categories/items, standard zeros, or asks where something belongs.
license: MIT
compatibility: Any filesystem-capable agent with read/write access to the vault. Notes are Markdown with YAML frontmatter. The bundled audit script needs Python 3.8+.
metadata:
  version: "0.1.0"
  spec: Agent Skills 1.0
---

# Johnny.Decimal in catalog space

A Johnny.Decimal (JD) system gives every folder and note a short, permanent number:
**Area → Category → Item**, written `CC.NN`. This skill encodes the *catalog-space*
variant: the vault is the **index**, and bulk data (media, models, projects) lives
outside sync and is only **referenced**. Standard JD co-locates files and their notes;
catalog space does not.

## How to use this skill

Start at the Quick Reference. Read the matching pattern before acting.

| Your task | Read first |
|-----------|-----------|
| Allocate a new number for a note or folder | `patterns/create-id.md` |
| Put a new note or file in the right place | `patterns/file-a-note.md` |
| Connect two notes | `patterns/link-notes.md` |
| Check a vault for spec compliance | `patterns/audit-vault.md` |
| Understand the numbering rules in full | `references/numbering-rules.md` |
| Understand catalog space vs. orthodox JD | `references/catalog-vs-orthodox.md` |

## The rules that matter (summary)

1. **Three levels only.** Area `1x` → Category `CC` → Item `CC.NN`. There is **no third
   segment**; below an item, use plain unnumbered grouping folders.
2. **Content IDs start at `.11`.** Zero-ending IDs are never content.
3. **Standard zeros** in every category: `.00` index · `.01` inbox · `.02` tasks ·
   `.03` templates · `.04` links · `.05` AI · `.06–.08` reserved · `.09` archive.
4. **`A0` categories are management.** The category ending in `0` manages the area
   (e.g. `10` manages area `10–19`).
5. **Numbers are opaque.** `12.34` is an address, not arithmetic. Never renumber an
   existing ID to "tidy up".
6. **Children/extensions use `+`** — `12.34+ Child's health`. Never invent `CC.DD.NN`.
7. **Link one way:** `Related:` goes **lower → higher**; backlinks cover the reverse.
8. **Catalog space:** reference bulk data; never move it into the vault.

## Gotchas

- Do **not** create `12.34.01`-style names. That is the single most common error.
- Do **not** use `.06`, `.07`, or `.08` — reserved for the standard zeros, even if empty.
- Do **not** start content at `.10`. Content starts at `.11`.
- When the user says "file this", ask which ID unless a folder already tells you — do
  not guess by searching the vault for a fuzzy match.
- Frontmatter is YAML (`jd:`, `type:`); do not convert notes to `> description` form
  unless the surrounding notes already use it.
