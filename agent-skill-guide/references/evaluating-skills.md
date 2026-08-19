# Evaluating Skill Output Quality

Eval-driven iteration for skills.

## Test cases
Three parts: Prompt, Expected output description, Input files.
Store in evals/evals.json.

## Running evals
Run each test case twice: with skill and without skill (or previous version). Clean context each run.

## Assertions
Verifiable statements about output. Add after first run.

Example assertion: "Output includes bar chart image file"

## Grading
PASS/FAIL with concrete evidence. Require evidence for PASS.

## Aggregating results
Compute benchmark: pass rate, time, tokens, delta between with/without.

## Analyzing patterns
- Remove assertions that always pass
- Investigate assertions that always fail
- Study assertions that pass with skill but fail without
- Tighten instructions when inconsistent

## Iterating
1. Give eval signals + current SKILL.md to LLM for proposals
2. Review and apply changes
3. Rerun evals in new iteration
4. Grade and aggregate
5. Human review
Repeat until satisfied.
