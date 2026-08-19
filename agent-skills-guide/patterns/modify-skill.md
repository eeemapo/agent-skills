# Modify Existing Skill

Edit frontmatter, restructure content, or update patterns/references.

## When to use
- Updating description
- Moving content from SKILL.md to patterns/references
- Adding new pattern files
- Fixing name/directory mismatch

## Steps
1. Read current SKILL.md
2. Identify what to move to patterns/references
3. Create new pattern file if needed
4. Update SKILL.md:
   - Update Quick Reference table
   - Update Patterns by Workflow section
   - Update frontmatter if changing name/description
5. Validate frontmatter constraints
6. Test skill with existing evals

## Moving content
If a section exceeds ~30 lines, move to patterns/<domain>.md.
If deep reference material, move to references/<topic>.md.

## Validation checklist
- Name matches directory
- Description ≤1024 chars
- Frontmatter valid
- File references one level deep
- SKILL.md under 500 lines
