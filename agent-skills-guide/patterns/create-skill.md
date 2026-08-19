# Create New Skill

Step-by-step workflow for scaffolding a new agent skill.

## 1. Plan
Decide:
- Skill name: lowercase-hyphenated
- Directory name: must match name
- Scope: domain covered
- Tools needed: list for allowed-tools

## 2. Create structure
```bash
mkdir -p skill-name/patterns
mkdir -p skill-name/references
```

## 3. Write SKILL.md frontmatter
```yaml
---
name: skill-name
description: 1-1024 chars, what it does AND when to use it
license: MIT
---
```

Validate name: lowercase, hyphens ok, no leading/trailing/consecutive hyphens, 1-64 chars, matches dir.

## 4. Write SKILL.md body
Include:
- Title
- How to use this skill
- Quick Reference table mapping task → pattern file
- Patterns by Workflow section
- Common Gotchas

Keep under 500 lines.

## 5. Create initial pattern files
Add patterns/ files for core workflows. Each pattern file should have:
- Title
- Use when
- Template/example
- Key rules
- Workflow example
- Notes

## 6. Validate
Run skills-ref validate and check frontmatter constraints.
