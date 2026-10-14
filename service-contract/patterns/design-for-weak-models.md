# Designing contracts for weak or local models

Assume the executing model is small, has a short effective planning horizon, and
will reconstruct anything you leave implicit. Design accordingly.

## Determinism beats prose

- Give a command to run, not a request to compose. "Run `scripts/<service>.sh
  auth`" is reliable; "POST to the auth endpoint with your key" is not.
- Prefer a checked-in script to a code block the model must copy correctly.

## One idea per command

- Each verb does one thing and returns one clear result.
- Use predictable, stable output (JSON or `key=value`) so the model does not
  parse prose.
- Fail loudly with a status and a short reason — never a silent empty result.

## Triggering is routing

- Put the concrete service name and its verbs in the description.
- Weak models match keywords. Names beat abstractions: a real service name
  triggers; "external service access" does not.
- Fewer skills, each well-scoped, route better than many tiny ones.

## Progressive disclosure, safely

- The hot path (auth, common verbs, gotchas) lives in SKILL.md and is
  self-contained.
- Deep reference material loads on demand — but do **not** make the common case
  depend on choosing among references; small models pick wrong.

## Guardrails

- Separate read verbs from write and destructive verbs.
- Require an explicit user decision for destructive verbs; make the safe read
  path the default.
- Never require the model to handle a secret in plaintext — let the script read
  it from the environment.

## Anti-patterns

- Long prose explaining a protocol the model must translate into a request.
- Hardcoded hosts or credentials "for now".
- A skill so broad it needs its own index.
- Relying on a weak model to infer which credential field to use.
