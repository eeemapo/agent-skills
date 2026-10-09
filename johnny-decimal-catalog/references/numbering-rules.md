# Numbering rules

## Levels

| Level | Form | Example |
|-------|------|---------|
| Area | `1x`, `2x` … | `10–19` |
| Category | `CC` | `12` |
| Item | `CC.NN` | `12.34` |

Three levels. There is no fourth. Below an item, folders are plain and unnumbered.

## Usable ranges

- **Areas:** `10–19` … `90–99`. Area `00–09` is system-reserved.
- **Categories:** `11`–`19`, `21`–`29`, … The category ending in `0` (`A0`) is the
  **management category** for its area (e.g. `10` manages `10–19`).
- **Items:** `.11`–`.99`. Zero-ending IDs are not content. `.00`–`.09` are the
  standard zeros.

## Standard zeros (per category)

| ID | Purpose |
|----|---------|
| `.00` | Index / JDex |
| `.01` | Inbox |
| `.02` | Tasks & project management |
| `.03` | Templates |
| `.04` | Links |
| `.05` | AI |
| `.06`, `.07`, `.08` | Reserved — do not use |
| `.09` | Archive |

The standard zeros repeat **verbatim** at every level: category `CC`, the
area-management category `A0` (e.g. `10.04 Links for area 10-19`), and the
system category `00`. When something belongs at a zero, prefer the most
specific one that fits.

`.09` is the **archive** — an append-only evidence layer (raw journals, decision
records, completed items, superseded snapshots), not a knowledge layer. Synthesise
the durable facts into the owning `CC.NN` note before filing there. See
`patterns/use-the-archive.md`.

Source of truth: <https://johnnydecimal.com/documentation/the-standard-zeros/>
(fetched 2026-10-02). `.05 AI` was added to the spec on 2026-09-07. `.06–.08`
are reserved for expansion — **do not use**. There is no `.08 Someday` in the
current spec; that was an older draft/RFC.

## The `+` extension

To note a child or a repeating item without a new segment, use `+`:

- `12.34+ Child's health` — a child of `12.34`.
- Useful when a third level would otherwise be invented. Prefer this over `12.34.01`.

## Invariants

- Numbers are opaque, unique, and permanent. The dot separates; it is not arithmetic.
- Never reuse a retired number.
- Sort order is automatic — do not reorder for aesthetics.
