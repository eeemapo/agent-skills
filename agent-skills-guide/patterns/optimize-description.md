# Optimize Skill Description

Improve description to trigger reliably.

## Steps
1. Create 20 eval queries: 8-10 should-trigger, 8-10 should-not-trigger with near-misses
2. Split into train and validation sets
3. Run current description against train set
4. Identify failures
5. Revise description: broaden if missing triggers, narrow if false triggers
6. Avoid overfitting: generalize, don't add specific keywords
7. Test against validation set
8. Repeat until validation pass rate plateaus

See references/optimizing-descriptions.md for detailed loop.
