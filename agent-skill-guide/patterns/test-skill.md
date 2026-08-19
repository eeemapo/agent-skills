# Test and Validate Skill

Validate spec compliance and output quality.

## Spec validation
Run the bundled validator:
```bash
python3 scripts/validate-skill.py path/to/skill
```
Or with skills-ref if installed:
```bash
skills-ref validate ./skill-name
```
Check:
- Frontmatter fields valid
- Name constraints
- Description length
- File references one level deep

## Description trigger testing
1. Create eval queries: should-trigger and should-not-trigger
2. Run multiple times, compute trigger rate
3. Revise description using optimizing-descriptions.md

## Output quality testing
1. Create evals/evals.json with prompts and expected outputs
2. Run with skill and without skill
3. Add assertions
4. Grade outputs with evidence
5. Aggregate benchmark
6. Iterate

## Pre-commit checklist
- [ ] Name matches directory
- [ ] Description 1-1024 chars
- [ ] Frontmatter valid
- [ ] SKILL.md <500 lines
- [ ] References one level deep
- [ ] Patterns registered in SKILL.md table
- [ ] Validation passed
