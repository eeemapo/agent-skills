# Knowledge Base Hook

Optional instance-specific context can live in a local Markdown knowledge base (KB).
Live resource state always comes from the Komodo API; the KB holds only what the API
cannot express.

## Location

- Base path: `$KB_ROOT` (no default; unset disables the hook).
- Any synced folder of Markdown files works — use normal file tools (read/grep/edit),
  no special client needed.

## Resolving an address

Notes are addressed by a short prefix, typically a number such as `10.24`. Resolve by
prefix, never by guessing a full path:

```bash
find "$KB_ROOT" -iname '10.24*'            # matching folder and note
find "$KB_ROOT" -maxdepth 3 -type d        # see the top level
```

If your vault uses a Johnny.Decimal-style scheme, an address like `10.24` reads as
area `10`, item `24`.

## Reading and writing notes

- **Read**: resolve the address, then read the matching `.md`.
- **Append** is preferred over rewriting: add a dated section rather than replacing
  content, so concurrent edits merge cleanly.
- Keep frontmatter small and stable (e.g. `tags`, `updated`).
- Prefer one topic per note.
- Large restructures should be deliberate if the vault syncs live to other devices.

## What belongs in the KB

| Belongs in KB | Belongs in the API (derive live) |
|---|---|
| Ownership, environment names, criticality | Servers, swarms, stacks, deployments and their state |
| Maintenance windows, change policy, contacts | Addresses/version/health |
| Naming conventions, aliases, external DNS | Container/image/volume inventory |
| Runbooks, decisions, history, credential **names** | Current logs, updates, action state |

## Secret policy

- Never store API keys, secrets, tokens, or full credential values in the KB.
- Reference an environment variable **name** or a secret-store path instead.
- Treat any synced note as readable on every device that syncs it.

## Contract for skills

The skill says "refer to `<address>` in the KB" and expects this resolution procedure.
If `$KB_ROOT` is unset or the address does not resolve, continue with live API discovery
and note the gap rather than failing.
