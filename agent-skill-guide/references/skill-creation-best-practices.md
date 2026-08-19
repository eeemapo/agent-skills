# Skill Creation Best Practices

## Start from real expertise
- Extract from a hands-on task with corrections and context
- Synthesize from existing artifacts: docs, runbooks, API specs, code review comments, version history

## Refine with real execution
First draft needs refinement. Run skill against real tasks, feed results back in. Read execution traces, not just final outputs.

## Spending context wisely
- Add what agent lacks, omit what it knows
- Design coherent units: encapsulate coherent work, not too narrow/broad
- Aim for moderate detail: concise stepwise guidance beats exhaustive docs
- Structure large skills with progressive disclosure: move detail to patterns/references, tell agent when to load

## Calibrating control
- Match specificity to fragility: freedom for flexible tasks, prescriptive for fragile sequences
- Provide defaults, not menus
- Favor procedures over declarations

## Effective patterns
- Gotchas: concrete corrections to mistakes
- Templates for output format
- Checklists for multi-step workflows
- Validation loops
- Plan-validate-execute
- Bundle reusable scripts
