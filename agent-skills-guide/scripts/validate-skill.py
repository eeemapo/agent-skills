#!/usr/bin/env python3
"""
Validate Agent Skills frontmatter.

Lightweight validator inspired by skills-ref. No external dependencies.
Usage:
  python scripts/validate-skill.py path/to/skill
  python scripts/validate-skill.py --help
"""
import re
import sys
from pathlib import Path

MAX_NAME = 64
MAX_DESC = 1024
MAX_COMPAT = 500

def parse_frontmatter(text):
    if not text.startswith('---'):
        return {}, text
    parts = text.split('---', 2)
    if len(parts) < 3:
        return {}, text
    fm = parts[1]
    body = parts[2]
    metadata = {}
    # Very small YAML subset for name/description/license/compatibility
    for line in fm.splitlines():
        if ':' not in line or line.strip().startswith('#'):
            continue
        k, v = line.split(':',1)
        k = k.strip()
        v = v.strip().strip('"').strip("'")
        metadata[k] = v
    return metadata, body

def validate_name(name, dir_name):
    errors = []
    if not name:
        errors.append("Missing name")
        return errors
    if len(name) > MAX_NAME:
        errors.append(f"name too long {len(name)} > {MAX_NAME}")
    if name != name.lower():
        errors.append("name must be lowercase")
    if name.startswith('-') or name.endswith('-'):
        errors.append("name cannot start/end with hyphen")
    if '--' in name:
        errors.append("name cannot contain consecutive hyphens")
    if not re.fullmatch(r'[a-z0-9-]+', name):
        errors.append("name contains invalid characters")
    if dir_name and dir_name != name:
        errors.append(f"directory name '{dir_name}' != skill name '{name}'")
    return errors

def validate_desc(desc):
    errors = []
    if not desc:
        errors.append("Missing description")
    elif len(desc) > MAX_DESC:
        errors.append(f"description too long {len(desc)} > {MAX_DESC}")
    return errors

def main():
    if len(sys.argv) == 1 or sys.argv[1] in ('-h','--help'):
        print("Usage: validate-skill.py path/to/skill")
        print("Validates Agent Skills frontmatter per specification.")
        print("Checks: name format, name-directory match, description length.")
        sys.exit(0)
    if len(sys.argv) < 2:
        print("Usage: validate-skill.py path/to/skill")
        sys.exit(1)
    skill_path = Path(sys.argv[1])
    skill_md = skill_path / 'SKILL.md'
    if not skill_md.exists():
        print(f"ERROR: {skill_md} not found")
        sys.exit(1)
    text = skill_md.read_text(encoding='utf-8')
    metadata, _ = parse_frontmatter(text)
    errors = []
    errors += validate_name(metadata.get('name',''), skill_path.name)
    errors += validate_desc(metadata.get('description',''))
    # Additional spec checks
    lines = text.splitlines()
    if len(lines) > 500:
        errors.append(f"SKILL.md has {len(lines)} lines, recommended <500")
    if errors:
        print("Validation errors:")
        for e in errors:
            print(f" - {e}")
        sys.exit(1)
    print(f"OK: {skill_path.name} is valid")
    sys.exit(0)

if __name__ == '__main__':
    main()
