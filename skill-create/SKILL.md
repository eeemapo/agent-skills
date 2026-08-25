---
name: skill-create
description: Create a new Agent Skill from scratch following the Agent Skills Specification. Use when scaffolding a brand-new skill — choosing its name and scope, writing SKILL.md frontmatter and body, organizing patterns/scripts/references/assets folders, bundling reusable scripts, or validating name/format/description. Also used when you need best-practices for skill scope, context budgeting, and calibrating control.
license: MIT
metadata:
  author: Ethan A
  version: "2.0"
---

# Skill Create — Build a New Skill

This skill helps you scaffold a new Agent Skill that follows the Agent Skills Specification. It is flattened: the core create workflow plus all reference material (spec, best-practices, scripts) is inlined here rather than spread across `references/*.md`.

## How to use this skill
Run the Create workflow below end-to-end. Apply whichever reference section matches the current need.

## Create workflow

Step-by-step workflow for scaffolding a new agent skill.

### 1. Plan
Decide:
- `<skill-name>`: lowercase-hyphenated
  - MUST BE lowercase, hyphens ok, no leading/trailing/consecutive hyphens, 1–64 chars
- Scope: identify the domain covered
- Patterns: identify common patterns (tool calls, scripts, steps, questions)
- Tools needed: list for `allowed-tools`
- Scripts needed: list of scripts to aid execution of the skill

### 2. Create structure
**NOTE**: minimum valid skill requires only the following structure:
```bash
mkdir <skill-name>
touch <skill-name>/SKILL.md
```
The sub-folders below are completely optional and can be added/removed/renamed at your discretion — they are examples, not requirements. Use them, skip them, or create new ones as you see fit.
- `<skill-name>/scripts` : Location for python, bash, or other executable scripts.
- `<skill-name>/patterns` : Location for 'sub-skills' or compartmentalized tasks needed to execute a step or aspect of a skill. (Useful for complex skills)
- `<skill-name>/references`: Location for static documentation used to assist with executing the skill. (Manuals, documentation, etc)

### 3. Write SKILL.md frontmatter
```yaml
---
name: <skill-name>
description: 1-1024 chars, what it does AND when to use it
license: MIT
metadata:
  author: <your-name>
---
```

### 4. Write SKILL.md body
Include:
- Title
- How to use this skill
- Quick Reference table
- Workflow section
- Common Gotchas

Keep under 500 lines / 5,000 tokens.

### 5. Create initial pattern files
Add `patterns/` files for core workflows. Each pattern file should have:
- Title
- Use when
- Template/example
- Key rules
- Workflow example
- Notes

### 6. Validate
Check: name format, name-directory match, description length (1–1024 chars), and hyphen rules.

## Progressive Disclosure Guidance

Progressive disclosure balances two costs: tool calls and context. You don't want to tax the model with a handful of reads just to load a skill, and you don't want to overload context with material that's rarely used. The guiding opinion here is that **SKILL.md should be the real "meat and potatoes"** — the actionable core — rather than a thin signpost to other files.

- **Keep in SKILL.md**: the core workflow, the rules the agent needs on most runs, and common gotchas. Reading `SKILL.md` alone should let the agent complete typical tasks without hunting through other files.
- **Offload to references/ (or scripts/patterns)**: only genuinely large or rarely-needed material — exhaustive example catalogs, full spec tables, long manuals, alternative strategies that apply to a minority of cases.
- **The tradeoff each way**: keeping content inline saves tool calls and avoids context churn from switching files; offloading saves context on rarely-used content but each load is an extra tool call and shifts context around. Too many loads makes `SKILL.md` a table of contents instead of the source of truth.
- **Practical heuristic**: if `SKILL.md` stays well under the 500-line / 5,000-token cap and is self-sufficient for common tasks, keep it inline. Offload only what would meaningfully bloat it or is needed rarely.
- **When offloading, leave a tight stub**: say *what* to load and *when* (e.g. "Load `references/skill-creation-best-practices.md` when scoping a large skill"), not just a bare filename. Prefer one well-targeted reference over several tiny stubs.

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

## Bundling Scripts Reference

### One-off commands
Reference existing tools directly in SKILL.md. Pin versions.

### Referencing scripts
Use relative paths from skill root:
```bash
bash scripts/validate.sh "$INPUT_FILE"
python3 scripts/process.py --input results.json
```

### Self-contained scripts
Bundle scripts in `scripts/` with inline dependencies:
- PEP 723 for Python
- Deno npm: `/` or `jsr:`
- Bun auto-install
- Bundler inline for Ruby

### Design for agentic use
- No interactive prompts; use flags/env/stdin.
- Document with `--help`.
- Helpful error messages with expected values.
- Structured output: stdout for data, stderr for diagnostics.
- Idempotent, clear exit codes, dry-run support, safe defaults.
- Predictable output size; support an `--output` flag.

## Common Gotchas
- Name must match directory exactly (invalidates frontmatter).
- No consecutive/leading/trailing hyphens in name.
- Description 1–1024 chars, non-empty.
- Keep SKILL.md under 500 lines / 5,000 tokens; split to patterns/references.
- File references one level deep only.
- Progressive disclosure matters: patterns/scripts load on demand.

## Tips
- Use progressive disclosure if the skill will take more than ~500 estimated lines to describe.
- Be flexible with structure — the minimal structure (SKILL.md) is all that's required to be a valid skill; anything added on top is also valid.
- Re-validate after changing name, description, or structure.
