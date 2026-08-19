# Optimizing Skill Descriptions

Description is primary trigger mechanism.

## Principles
- Use imperative phrasing: "Use this skill when..."
- Focus on user intent, not implementation
- Err on side of being pushy: list contexts explicitly
- Keep concise, under 1024 chars

## Optimization loop
1. Create eval queries: ~20 queries, 8-10 should-trigger, 8-10 should-not-trigger with near-misses
2. Test trigger rate with multiple runs
3. Split train/validation sets to avoid overfitting
4. Revise description based on failures
5. Select best iteration by validation pass rate

## Avoid overfitting
- Don't add specific keywords from failed queries; find general category
- Use train set for changes, validation set for selection
- Five iterations usually enough

## Example improvement
Before: `description: Process CSV files.`
After: `description: Analyze CSV and tabular data files — compute summary statistics, add derived columns, generate charts, and clean messy data. Use this skill when the user has a CSV, TSV, or Excel file and wants to explore, transform, or visualize the data, even if they don't explicitly mention "CSV" or "analysis."`
