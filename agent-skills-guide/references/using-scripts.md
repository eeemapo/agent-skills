# Using Scripts in Skills

## One-off commands
Reference existing tools directly in SKILL.md. Pin versions.

## Referencing scripts
Use relative paths from skill root:
```bash
bash scripts/validate.sh "$INPUT_FILE"
python3 scripts/process.py --input results.json
```

## Self-contained scripts
Bundle scripts in scripts/ with inline dependencies:
- PEP 723 for Python
- Deno npm: / jsr:
- Bun auto-install
- Bundler inline for Ruby

## Design for agentic use
- No interactive prompts; use flags/env/stdin
- Document with --help
- Helpful error messages with expected values
- Structured output, stdout for data, stderr for diagnostics
- Idempotent, clear exit codes, dry-run support, safe defaults
- Predictable output size, support --output flag
