# Authoring a service contract

Goal: a skill that lets an agent authenticate and act on one service reliably,
on the first try, without leaking environment specifics.

## 1. Scope it

One service, or one tight capability of a service. If the description needs the
word "and" more than once, split it.

## 2. Capture a known-good invocation

You cannot write a reliable contract from a guess. Get one that actually works,
from the strongest available source:

- A working session (yours or a larger model's) — the exact command or request.
- The service's own docs or OpenAPI description.
- The service's client library or UI JavaScript (as a last resort).

Record verbatim: the endpoint, the method, the auth scheme, the parameter
**names**, which credential field is used, and the success and failure signals.

## 3. Reduce it to a script

Turn the capture into `scripts/<service>.sh` with:

- a `--help` listing the verbs;
- one subcommand per verb (`auth`, `read`, `list`, `act`);
- configuration (base URL, credential) read from **environment variables** with
  documented names — never literals;
- stable, parseable output; **never** print secret values;
- clear non-zero exits and a short human-readable line on failure.

The model should be able to run one command and read the result — no assembly.

## 4. Enumerate the traps

This is the highest-value part of the skill: the compressed experience of
whoever got it working. For each thing that *looked right but failed*, add a
line under **Gotchas** — the exact string, and what it should be.

## 5. Write the description for triggering

Name the service with concrete nouns and list the verbs. Descriptions are a
routing table; a weak model picks the skill by matching words, not by reasoning
about abstractions.

## 6. Keep the hot path thin

SKILL.md carries the common case (auth, one or two verbs, gotchas). Deep API
detail goes to `references/`, loaded only when needed.

## 7. Validate and evaluate

- Validate against the Agent Skills spec.
- Run [`evaluate-against-a-model.md`](evaluate-against-a-model.md) with the
  weakest model you intend to support. Iterate until the bare task passes in a
  small number of turns.

## Checklist

- [ ] One service, or one capability
- [ ] Known-good invocation captured, not guessed
- [ ] `scripts/` performs the exact request; environment-configured
- [ ] Gotchas list states the exact strings that trip models
- [ ] Description names the service and the verbs
- [ ] SKILL.md hot path self-contained; deep detail in `references/`
- [ ] No real host, credential, or path anywhere
- [ ] Passes spec validation and a model eval
