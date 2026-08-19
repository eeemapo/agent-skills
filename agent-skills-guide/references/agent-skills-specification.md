# Agent Skills Specification

Source: https://agentskills.io/specification

## Directory structure
```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional
├── references/       # Optional
├── assets/           # Optional
```

## SKILL.md format

YAML frontmatter + Markdown body.

### Frontmatter

| Field | Required | Constraints |
|-------|----------|-------------|
| name | Yes | 1-64 chars, lowercase a-z 0-9 hyphens, no leading/trailing/consecutive hyphens, must match parent directory name |
| description | Yes | 1-1024 chars, non-empty, describes what skill does and when to use it |
| license | No | Name or reference to bundled file |
| compatibility | No | Max 500 chars, environment requirements |
| metadata | No | Arbitrary string→string map |
| allowed-tools | No | Space-separated experimental field |

### Body content
Markdown instructions. Recommended: step-by-step instructions, examples, edge cases.

Keep SKILL.md under 500 lines / 5,000 tokens. Move detailed material to references/.

### Progressive disclosure
1. Metadata ~100 tokens: name + description loaded at startup
2. Instructions <5000 tokens: full SKILL.md loaded on activation
3. Resources as needed: scripts/, references/, assets/ loaded on demand

### File references
Use relative paths from skill root, one level deep:
```
SKILL.md → patterns/*.md
SKILL.md → references/*.md
```

### Validation
Use skills-ref to validate frontmatter and naming conventions.
