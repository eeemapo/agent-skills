---
name: skill-validate
description: Validate an Agent Skill for conformance to the Agent Skills Specification. Use when checking a skill against the spec (frontmatter validity, name/directory match, description length 1–1024, one-level-deep references, SKILL.md size) and fixing it to conform. Also use when you need the validation checklist or want to run the bundled validator on a skill path. Description trigger testing and eval-driven output-quality grading are provided as optional extras but are out of scope for pure conformance.
license: MIT
metadata:
  author: agentskills
  version: "1.0"
---

# Skill Validate — Check & Grade a Skill

This skill lints an Agent Skill for **conformance to the Agent Skills Specification** and, optionally, grades output quality. It is flattened: the spec rules, validation workflow, trigger testing, and pre-commit checklist are all inlined here, with the bundled validator doing the mechanical checks. Run it like a linter/LSP tool: it prints a structured report of what passed, warned, and failed.

## How to use this skill
Run the bundled validator against a skill, review the PASS/WARN/FAIL report, fix failures, and re-run until the summary reads `Result: VALID`.

## Validation workflow
1. Run the validator with the **full path** to the skill (or directly to its `SKILL.md`):
   ```bash
   bash scripts/validate-skill.sh /full/path/to/skill
   # or validate a specific file:
   bash scripts/validate-skill.sh /full/path/to/SKILL.md
   ```
   The argument may be a skill directory (uses `<dir>/SKILL.md`) or a `SKILL.md` file directly.
2. Read the structured report: each check is tagged `[PASS]`, `[WARN]`, or `[FAIL]`. Warnings are non-fatal; failures are not.
3. Fix each **FAIL** in the target skill (warnings are optional improvements).
4. Re-run until the summary prints `Result: VALID` (exit code `0`).

Use `--json` for a machine-readable report to feed into tooling or an LLM:
```bash
bash scripts/validate-skill.sh --json /full/path/to/skill
```

## What the validator checks
Each check is tagged `[PASS]`, `[WARN]` (non-fatal), or `[FAIL]`. Exit code is `1` when any check FAILs, else `0`.

- **Structure**: `SKILL.md` present; frontmatter delimited by `--- … ---`
- **Name**: present; length ≤ 64; lowercase; no leading/trailing hyphens; no consecutive hyphens; charset `[a-z0-9-]`; matches parent directory name
- **Description**: present; length ≤ 1024
- **Optional fields**: `compatibility` length ≤ 500; `license` points to an existing bundled file when it names one; `allowed-tools` is space-separated
- **Body**: `SKILL.md` < 500 lines and < ~5000 tokens (soft checks)
- **References**: markdown links resolve to files that exist and sit one level deep (`patterns/…`, `references/…`, etc.)
- **YAML**: unquoted frontmatter values containing `: ` or ending with `:` (which make strict YAML parsers read them as nested mappings)

Run the validator with the full path to a skill directory or directly to a `SKILL.md` file — see the workflow above. Run `bash scripts/validate-skill.sh --help` for usage.

## Spec compliance rules (reference)

Source: Agent Skills Specification (https://agentskills.io/specification).

### Directory structure
```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional
├── references/       # Optional
└── assets/           # Optional
```

### Frontmatter fields
| Field | Required | Constraints |
|-------|----------|-------------|
| name | Yes | 1–64 chars, lowercase a-z 0-9 hyphens, no leading/trailing/consecutive hyphens, must match parent directory name |
| description | Yes | 1–1024 chars, non-empty, describes what skill does and when to use it |
| license | No | Name or reference to bundled file |
| compatibility | No | Max 500 chars, environment requirements |
| metadata | No | Arbitrary string→string map |
| allowed-tools | No | Space-separated experimental field |

### Body content
Markdown instructions. Recommended structure: step-by-step instructions, examples, edge cases. Keep `SKILL.md` under 500 lines / 5,000 tokens; move detailed material to `references/`.

### File references
Use relative paths from skill root, one level deep:
```
SKILL.md → patterns/*.md
SKILL.md → references/*.md
```

## Description trigger testing (optional)
Use when improving how reliably a skill's description triggers (a "making it better" tweak, not pure conformance).
1. Create eval queries: 8–10 should-trigger, 8–10 should-not-trigger with near-misses.
2. Run multiple times, compute trigger rate.
3. Revise the description using the optimizing-descriptions guidance (broaden if missing triggers, narrow if false triggers; generalize categories rather than bolting on keywords).

## Output quality testing (optional)
Use when measuring how well a skill improves task outcomes (out of scope for pure conformance).
1. Create `evals/evals.json` with test cases (prompt, expected output description, input files).
2. Run each case twice: with the skill and without it (or a prior version), clearing context between runs.
3. Add verifiable assertions after the first run.
4. Grade PASS/FAIL with concrete evidence (require evidence for PASS).
5. Aggregate: pass rate, time, tokens, delta with vs without.
6. Analyze patterns (assertions that always pass / always fail / pass-with-skill-only) and iterate until satisfied.

## Pre-commit checklist
- [ ] Name matches directory
- [ ] Name format valid (lowercase, hyphens, ≤ 64 chars)
- [ ] Description 1–1024 chars
- [ ] Frontmatter valid
- [ ] SKILL.md < 500 lines
- [ ] References one level deep only
- [ ] Validation passed (`Result: VALID`, exit code `0`)

## Common Gotchas
- Name must match directory exactly.
- Description 1–1024 chars.
- Frontmatter valid; SKILL.md < 500 lines.
- References one level deep only.
- Use train/validation split so trigger tests don't overfit.
- Require concrete evidence before grading an eval PASS.
