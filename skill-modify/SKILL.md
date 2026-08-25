---
name: skill-modify
description: Modify and/or optimize an existing Agent Skill. Use when editing a skill, restructuring skill files, updating the frontmatter description, or improving how reliably the skill triggers. Also use when moving content between SKILL.md and patterns/, references/, scripts/, or assets/ folders, or fixing name/directory mismatches.
license: MIT
metadata:
  author: Ethan A
  version: "2.0"
---

# Skill Modify — Edit & Optimize a Skill

This skill helps you modify an existing Agent Skill and optimize its information delivery and trigger reliability. It is flattened: all material — procedure, specification details, description optimization, and best-practices — is inlined here rather than spread across `references/*.md`.

## How to use this skill
Read this file completely. Then follow the procedure below as needed. The reference sections that follow (Frontmatter & Structure, Description Optimization, Best Practices, Gotchas) contain the detailed rules; apply whichever applies to the current task.

## Sections

| Your task involves... | Read |
|----------------------|------|
| Modifying an existing skill, updating description, moving content | `Modify Skill Procedure` |
| Optimizing description for triggering | `Optimize-description Skill Procedure` |
| Understanding format rules | `Frontmatter & Structure Reference` |
| Designing skill content | `Best Practices Reference` |

## Modify Skill Procedure

Edit frontmatter, restructure content, or update supplementary files and folders in the skill.

### When to use
- Updating description
- Moving content from SKILL.md to patterns, references, scripts, etc.
- Adding new files and folders
- Fixing name/directory mismatch

### Steps
1. Read current SKILL.md and inspect any `references/`, `scripts/`, `assets/` folders.
2. Identify what to move and edit.
3. Create new files and folders if needed.
4. Update SKILL.md:
   - Update or add references to any changed or moved files and folders.
   - Update frontmatter if changing name/description.

### Moving content
If a section exceeds ~30 lines, move it to a new file and leave a reference stub pointing to it. For deep reference material, place it in `references/<topic>.md`. When flattening, merge everything into SKILL.md instead.

## Optimize-description Skill Procedure

Improve the description so it triggers reliably.

1. Create ~20 eval queries: 8–10 should-trigger, 8–10 should-not-trigger with near-misses.
2. Split into train and validation sets (to avoid overfitting).
3. Run the current description against the train set; identify failures.
4. Revise: broaden if missing triggers, narrow if false triggers.
5. Avoid overfitting: generalize to the category, don't bolt on specific failed-query keywords.
6. Test against the validation set.
7. Repeat until the validation pass rate plateaus (usually ~5 iterations).

See `Best Practices Reference` and `Frontmatter & Structure Reference` for rules and examples that constrain the description.

## Progressive Disclosure Guidance

Progressive disclosure is about balancing two costs: tool calls and context. You don't want to tax the model with a handful of reads just to load a skill, and you don't want to overload context with material that's rarely used. The guiding opinion here is that **SKILL.md should be the real "meat and potatoes"** — the actionable core — rather than a thin signpost to other files.

- **Keep in SKILL.md**: the core workflow, the rules the agent needs on most runs, and common gotchas. Reading `SKILL.md` alone should let the agent complete typical tasks without hunting through other files.
- **Offload to references/ (or scripts/patterns)**: only genuinely large or rarely-needed material — exhaustive example catalogs, full spec tables, long manuals, alternative strategies that apply to a minority of cases.
- **The tradeoff each way**: keeping content inline saves tool calls and avoids context churn from switching files; offloading saves context on rarely-used content but each load is an extra tool call and shifts context around. Too many loads makes `SKILL.md` a table of contents instead of the source of truth.
- **Practical heuristic**: if `SKILL.md` stays well under the 500-line / 5,000-token cap and is self-sufficient for common tasks, keep it inline. Offload only what would meaningfully bloat it or is needed rarely.
- **When offloading, leave a tight stub**: say *what* to load and *when* (e.g. "Run `references/optimizing-descriptions.md` when tuning the trigger description"), not just a bare filename. Prefer one well-targeted reference over several tiny stubs.

## Frontmatter & Structure Reference

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
Markdown instructions. Recommended structure: step-by-step instructions, examples, edge cases. Keep SKILL.md under 500 lines / 5,000 tokens; move detailed material to `references/` (or inline it when flattening).

### Progressive disclosure
1. Metadata (~100 tokens): name + description loaded at startup.
2. Instructions (<5000 tokens): full SKILL.md loaded on activation.
3. Resources as needed: `scripts/`, `references/`, `assets/` loaded on demand.

### File references
Use relative paths from skill root, one level deep:
```
SKILL.md → patterns/*.md
SKILL.md → references/*.md
```

### Validation
Validate frontmatter and naming conventions (name matches directory, description within 1–1024 chars, hyphen rules) before finishing.

## Best Practices Reference

### Start from real expertise
- Extract from a hands-on task with corrections and context.
- Synthesize from existing artifacts: docs, runbooks, API specs, code review comments, version history.

### Refine with real execution
First draft needs refinement. Run the skill against real tasks and feed results back in. Read execution traces, not just final outputs.

### Spending context wisely
- Add what the agent lacks; omit what it knows.
- Design coherent units: encapsulate coherent work, not too narrow or broad.
- Aim for moderate detail: concise stepwise guidance beats exhaustive docs.
- Structure large skills with progressive disclosure: move detail to patterns/references, tell the agent when to load.

### Calibrating control
- Match specificity to fragility: freedom for flexible tasks, prescriptive for fragile sequences.
- Provide defaults, not menus.
- Favor procedures over declarations.

### Effective patterns
- Gotchas: concrete corrections to mistakes.
- Templates for output format.
- Checklists for multi-step workflows.
- Validation loops.
- Plan-validate-execute.
- Bundle reusable scripts.

## Description Optimization Reference

The description is the primary trigger mechanism.

### Principles
- Use imperative phrasing: "Use this skill when..."
- Focus on user intent, not implementation.
- Err on the side of being pushy: list contexts explicitly.
- Keep concise, under 1024 chars.

### Optimization loop
1. Create eval queries: ~20 queries, 8–10 should-trigger, 8–10 should-not-trigger with near-misses.
2. Test trigger rate with multiple runs.
3. Split train/validation sets to avoid overfitting.
4. Revise description based on failures.
5. Select best iteration by validation pass rate.

### Avoid overfitting
- Don't add specific keywords from failed queries; find the general category.
- Use the train set for changes, the validation set for selection.
- Five iterations usually enough.

### Example improvement
Before: `description: Process CSV files.`
After: `description: Analyze CSV and tabular data files — compute summary statistics, add derived columns, generate charts, and clean messy data. Use this skill when the user has a CSV, TSV, or Excel file and wants to explore, transform, or visualize the data, even if they don't explicitly mention "CSV" or "analysis."`

## Common Gotchas
- Name must match directory exactly (invalidates frontmatter).
- Description 1–1024 chars, non-empty.
- File references one level deep only.
- No consecutive/leading/trailing hyphens in name.
- Avoid overfitting: generalize, don't bolt on failed-query keywords.

## Tips
- Keep name matching directory after a rename.
- Move sections >~30 lines to patterns/, deep material to references/.
- Description: keep it pushy but honest (list explicit contexts).
- Validate + re-run trigger evals after every description change.
