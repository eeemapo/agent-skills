# Knowledge Base Hook

Live resource state always comes from the Komodo API — derive it, never read it from a note.
A local Markdown knowledge base (KB) holds only what the API **cannot** express: this
homelab's conventions, ownership, and the traps that come from how things are actually built.

**The notes are canonical.** This skill routes to them; it never copies them.

## Location

- Base path: `$KB_ROOT` (default `~/notes/main`; set an empty value to disable).
- Any synced folder of Markdown works — use normal file tools (read/grep/edit). No special
  client, and no need to sync by hand: `ob sync-status --path "$KA"` says whether an edit has
  synced. Notes are personal and replicated to other devices; treat them as readable
  everywhere.

## Resolving an address

Notes are addressed by a short Johnny.Decimal prefix (`CC.NN`). Resolve by prefix, never by
guessing a full path:

```bash
KA="${KB_ROOT:-$HOME/notes/main}"
find "$KA" -iname '14.13*'          # the matching folder and note
find "$KA" -maxdepth 3 -type d      # the top level, if you need orientation
```

An address resolves to the folder/note whose name starts with that number.

**Read the addressed note, do not browse the vault.** The catalog is large and mostly
irrelevant to a Komodo task; a pinned address is a bounded read, a browse is a distraction.

## Instance defaults (this deployment)

| Subject | Address | Read it when |
|---------|---------|--------------|
| **Stack operations** — stack kinds, how to edit each, secrets injection, lifecycle, verification | `14.13` | **before editing or deploying any stack** |
| Secrets injection via 1Password Connect (`compose_cmd_wrapper`, `op run`) | `14.17` | touching how a stack gets its secrets |
| Tailscale sidecar wiring and its traps | `14.12` | a stack uses `network_mode: service:ts`, or comes back unreachable |
| Homelab topology (hosts, roles, Komodo Core) | `14.11` | you need to know what a server *is* |
| Homelab networking (subnets, DNS, VPN) | `14.12` | addresses, DNS, or ingress are involved |

The vault root is `~/notes/main`. Komodo endpoint and credentials live in pi's `auth.json`
`komodo` entry; notes record env var and credential **names**, never values.

## What belongs in the KB

| Belongs in the KB | Derive live from the API |
|---|---|
| Ownership, environment names, criticality | servers, swarms, stacks, deployments and their state |
| Maintenance windows, change policy, contacts | addresses, version, health |
| Naming conventions, aliases, external DNS | container/image/volume inventory |
| Runbooks, decisions, history, credential **names** | current logs, updates, action state |
| *How this homelab expects a stack to be built* | what a stack currently contains |

If a fact is one API call away, calling the API wins: it cannot go stale.

## Reading and writing notes

- **Read**: resolve the address, then read the matching `.md`.
- **Append** rather than rewrite — add a dated section so concurrent edits merge cleanly.
- Keep frontmatter small and stable (`tags`, `updated`, `jd`).
- One topic per note.
- Structural changes (renames, re-filing) are deliberate, not incidental — the vault syncs
  live to other devices. Follow the Johnny.Decimal catalog conventions for those.
- Confirm sync afterwards with `ob sync-status --path "$KA"`.

## Secret policy

- Never store API keys, secrets, tokens, or full credential values in the KB — including a
  `K_…`/`S_…` pair returned by `komodo_user_create_api_key` or `CreateApiKeyForServiceUser`.
- Reference an environment variable **name** or a secret-store path (`op://…`) instead.
- Any synced note is readable on every device that syncs it.

## Contract for skills

This skill says "refer to `<address>` in the KB" and expects the resolution procedure above.

- If `$KB_ROOT` is unset or the address does not resolve, **continue with live API
  discovery** and say the gap out loud rather than failing or guessing.
- **One canonical source:** conventions live in the note, not in this skill. If a convention
  needs to change, change the note. Copying note content into a skill creates a second truth
  that drifts.
- A convention that must be obeyed *before* the agent would think to read a note belongs
  inline in `SKILL.md` as a safety rule (the sidecar and `litellm` traps are there for
  exactly that reason) — inline the invariant, point at the note for the detail.
