# Audit a vault

**Use when** asked whether a vault is JD-compliant, or before/after a bulk refactor.

## Steps

1. Run the bundled script:

   ```bash
   python3 scripts/audit_jd.py /path/to/vault
   ```

2. It reports four classes of problem:
   - **third-segment** names (`CC.DD.NN`) — must not exist,
   - **zero-ending content IDs** (`.10`, `.20`, …) — content must start at `.11`,
   - **reserved slots used** (`.06`, `.07`, `.08`),
   - **top-level entries** that do not look like `CC-Name`.
3. Fix findings with the owner's approval. Never auto-renumber.
4. Re-run until clean.

## Key rules

- Renumbering is destructive to memory and links — always confirm first.
- Prefer renaming the *name* over changing the *number*.
- After any bulk change, verify no note references an old path, then sync.

## Manual checks

- Does every category have a `.00` index?
- Are working slots the standard zeros (`.01` inbox, `.02` task & project
  management, `.03` templates, `.04` links, `.05` AI, `.09` archive)?
- Is anything numbered below an item?
