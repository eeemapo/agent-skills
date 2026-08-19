---
name: agent-skill-guide
description: Create, modify, and test Agent Skills per the Agent Skills specification. Use when building a new skill, extending an existing skill's patterns/references, restructuring a skill's file organization per the spec, validating frontmatter, optimizing descriptions for triggering, or evaluating skill output quality. This skill provides progressive-disclosure guidance via patterns/ and references/.
license: CC-BY-4.0
metadata:
  author: agentskills
  version: "1.0"
---

# Agent Skills Guide — Create, Modify & Test Skills

This skill helps you create, modify, and test Agent Skills that follow the Agent Skills Specification. It uses progressive disclosure: SKILL.md provides navigation, `patterns/*.md` provide step-by-step workflows, and `references/*.md` provide deep spec material loaded on demand.

Source hierarchy: **SKILL.md** → **`patterns/*.md`** → **`references/*.md`**

## How to use this skill
Start at the Quick Reference table below. Read the matching pattern file first, then validate.

## Quick Reference

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| Creating a brand new skill from scratch | `patterns/create-skill.md` | Full scaffolding + frontmatter validation |
| Modifying an existing skill, updating description, moving content | `patterns/modify-skill.md` | Editing frontmatter, restructuring, validation |
| Testing skill spec compliance or output quality | `patterns/test-skill.md` | Validation checklist + eval-driven testing |
| Optimizing description for triggering | `patterns/optimize-description.md` | Trigger evals and description refinement loop |
| Understanding spec constraints | `references/agent-skills-specification.md` | Full spec for frontmatter, naming, structure |

## Patterns by Workflow

### 🆕 Creating Skills
- **[`patterns/create-skill.md`](patterns/create-skill.md)** — Scaffold a new skill directory from scratch
  - → `read` this when creating a new skill for the first time
  - Frontmatter template · Naming validation · Directory scaffolding

### ✏️ Modifying Skills
- **[`patterns/modify-skill.md`](patterns/modify-skill.md)** — Edit existing skill: frontmatter updates, restructuring, validation
  - → `read` this when changing descriptions, moving content between files
  - Frontmatter editing · Move content to patterns/references · Validate after edits

### ✅ Testing & Validating
- **[`patterns/test-skill.md`](patterns/test-skill.md)** — Complete spec validation and output quality testing
  - → `read` this before committing changes
  - Frontmatter checks · File references · Structure · Pre-commit list

- **[`patterns/optimize-description.md`](patterns/optimize-description.md)** — Systematically improve description triggering
  - → `read` this when description isn't triggering correctly
  - Trigger evals · Train/validation split · Optimization loop

## Reference Materials

Read only when needed:
- **[`references/agent-skills-specification.md`](references/agent-skills-specification.md)** — Full Agent Skills spec
- **[`references/skill-creation-best-practices.md`](references/skill-creation-best-practices.md)** — Best practices for scope, context, control
- **[`references/optimizing-descriptions.md`](references/optimizing-descriptions.md)** — Detailed description optimization guide
- **[`references/using-scripts.md`](references/using-scripts.md)** — Bundling scripts and designing for agentic use
- **[`references/evaluating-skills.md`](references/evaluating-skills.md)** — Eval-driven iteration for output quality

## Common Gotchas

- Name must match directory exactly
- No consecutive hyphens, no leading/trailing hyphens
- Description ≤1024 chars
- Keep SKILL.md under 500 lines; split to patterns/references
- File references one level deep only
- Progressive disclosure matters: patterns load on demand
