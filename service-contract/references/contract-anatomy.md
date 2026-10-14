# Contract anatomy

The canonical layout of a service-contract skill:

    <service>/
      SKILL.md          # thin hot path: when to use, verbs, gotchas
      patterns/         # step-by-step workflows (load on demand)
      references/       # deep API spec, schemas (load on demand)
      scripts/          # the deterministic verbs (run on demand)
      assets/           # optional fixtures, request samples

## SKILL.md

- Frontmatter: `name` (matches the directory), `description` (1-1024 chars,
  names the service and the verbs), `license`, `compatibility`, `metadata`.
- Body: a one-paragraph purpose, a Quick Reference table
  (`task -> file or command`), the non-negotiables, and a Gotchas section.
- Keep it under about 500 lines; the common case must be completable from here.

## patterns/

Workflows the agent follows for non-trivial tasks: author, design, evaluate,
rotate, and similar. One file per workflow.

## references/

Deep, rarely-needed detail: full endpoint catalogs, request and response
schemas, error shapes, pagination, rate limits. Loaded only when the hot path is
insufficient.

## scripts/

The exact, executable work. One entry point (`<service>.sh`) with subcommands.
Configuration from environment variables. Stable output. No secret echoing.

## assets/

Optional. Fixtures, sample payloads, config templates.

## File references

One level deep only: SKILL.md points into `patterns/`, `references/`, or
`scripts/`. Do not chain references into further references.
