# Link notes

**Use when** two notes or IDs are related.

## Steps

1. Identify the two IDs.
2. Add a `Related:` entry in the **lower-numbered** note only, pointing at the higher.
3. Use a wiki-link: `Related: [[12.34 Related note]]`.
4. Do **not** add the reverse link — the reader provides backlinks.

## Key rules

- One direction only: lower → higher. This keeps the graph acyclic and prevents
  duplicate, drifting link text.
- Link IDs, not file paths, wherever the tool supports it.
- A note may link to several higher numbers; it should not link "downward".

## Example

In `12.31` you reference `12.34`, a related note:

```markdown
Related:
- [[12.34 Related note]]
```
