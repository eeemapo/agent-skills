# Catalog space vs. orthodox Johnny.Decimal

## Orthodox JD

Files and their notes **co-locate**: the ID `12.34` holds both the notes about a topic
and the associated files. The number is a shared address for content and
documentation.

## Catalog space

The vault is a **card catalog**: it indexes everything, and the bulk data lives
elsewhere (external drives, app libraries, cloud storage) and is **referenced**, not
stored. `12.34` holds a *note about* an asset; the asset itself lives outside the vault.

## Why choose it

Sync ceilings. An Obsidian-sync vault is optimised for small text files; pulling
terabytes of media into it breaks immediately. Catalog space keeps the index small and
portable.

## What stays orthodox

Everything about numbering — areas, categories, items, standard zeros, no third
segment, one-way links. Only the **co-location** is dropped.

## Consequences

- A note may need a `Data:` pointer or URL instead of an embedded file.
- "Where is X?" answers with *an address plus a location*, not just a folder.
- Never run an orthodox "move files in" workflow against a catalog-space vault.
