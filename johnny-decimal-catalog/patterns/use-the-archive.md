# Use the archive

**Use when** something is finished, superseded, or raw — a completed action item, a
session/journal ("war") log, a scoping or decision record, or a snapshot you are
replacing.

Every category `CC` has an archive slot: **`CC.09`** (area-management `A0.09`, system
`00.09` too). The archive is the **evidence layer**, not a knowledge layer — getting
that distinction right *is* the skill.

## The rule: synthesise, then archive

Historical material is **evidence**; operational truth is **knowledge**.

- **Knowledge** — how the system works *now* — lives in the content item `CC.NN`:
  current state, no journey, no done-checkboxes.
- **Evidence** — how you got there, what you tried, raw logs — lives in `CC.09`.

Before anything goes into `.09`, its durable facts must already be stated, as *current
state*, in the owning content note. If they are not, write them there **first** — that
is the "synthesise" half. Then file the raw record and link it upward.

**Never let `.09` become the only place a fact exists.**

## What goes in

| Goes in `.09` | Stays out |
|---|---|
| Raw session / journal / war logs | Current-state reference (→ `CC.NN`) |
| Completed-action-item records | Live, open tasks (→ `CC.02`) |
| Scoping / decision records | Anything you will keep editing |
| Superseded snapshots | A second copy of what is already in `CC.NN` |

## Retiring an item vs. filing evidence

- **Retiring an item:** move the whole `CC.NN` item into `CC.09/` — the number never
  changes (numbers are permanent).
- **Filing evidence:** raw material that never had its own content number (journals,
  logs, completed-work records) gets a dated filename and the archive address
  `CC.09`.

## Layout — plain folders only

Below the archive slot, group with **plain, unnumbered** folders. Never invent a third
number segment (`CC.09.01`) and never renumber.

```
14.09-Archive/
  journals/   YYYY-MM-<topic>.md        # raw, cross-cutting, chronological
  records/    YYYY-MM-<topic>.md        # scoping / decision / completed-work
  completed/  <CC.02>-board-archive.md  # completed-item mirror
```

Keeping it flat with dated names is also fine — pick one per vault and be consistent.

## Front matter

```yaml
---
jd: "CC.09"            # the archive address
type: journal          # journal | archive
archived: 2026-10-09   # date filed
covers: [CC.15, CC.17] # categories this evidence touches
superseded-by: "[[CC.NN Living note]]"   # the note that distils it (optional)
---
```

`covers:` keeps evidence findable by topic even though its own number only says
"archive"; `superseded-by:` is the upward link back to the knowledge.

## Anti-patterns

- A "living" note that is mostly a changelog of what you did — move the changelog to
  `.09`, keep the current state.
- An archive used as a second inbox — file it, date it, link it, leave it.
- Copying facts into `.09` but **not** into `CC.NN` — the archive must never be the
  source of truth.
