# File a note

**Use when** something new needs a home.

## Decide the destination

- Category-agnostic, unsorted → the relevant `AC.01-Inbox/`.
- Belongs to an existing item → that item's folder, as a plain child.
- Needs to be grouped inside an item → a **plain, unnumbered** subfolder.
- New subject with no item → create an ID first (`patterns/create-id.md`).

## Steps

1. Choose the ID or slot.
2. Write the note with YAML frontmatter. Set `jd:` to its ID, `type:` to what it is.
3. Place assets (images, PDFs) inside the item's folder or a plain grouping subfolder.
4. If it relates to another note, add a one-way `Related:` link.

## Key rules

- **No new number segments.** Deeper than an item is a plain folder name.
- **Do not move bulk data into the vault.** In catalog space, link to it:
  `Data:` / `URL:`, or a reference note. Sync size is the reason this variant exists.
- Inboxes are temporary. Anything you place there should be sorted soon.

## Note template

```markdown
---
jd: "12.34"
type: reference
---
# 12.34 — Title

One-line summary.

## Notes

- ...

## Related

- [[11.11 Another note]]
```
