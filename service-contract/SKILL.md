---
name: service-contract
description: Author, review, and evaluate "service contract" skills — skills that let an agent authenticate to and operate a networked service (API or CLI) deterministically. Use when writing a skill for a service (auth, read, list, act), when a weaker or local model can find credentials but cannot reproduce the exact request shape, when turning a one-off working command into something a model can repeat reliably, or when testing whether a skill actually works against a target model. Covers contract anatomy, script-first design, portability and secret hygiene (no hardcoded hosts or credentials), and an eval-driven iteration loop.
license: MIT
compatibility: Client-agnostic. Assumes the agent can run shell commands and read files. Using this skill needs no network access; the contracts it produces do.
metadata:
  version: "1.0"
  spec: Agent Skills 1.0
---

# Service Contracts

A **service contract skill** teaches an agent how to authenticate to and operate
one service — its auth handshake, its verbs, and the traps — without the agent
having to reconstruct the wire format from general knowledge.

## Why this exists

Two failures look alike but are not:

- **Discovery** — "where do credentials live?" Fix with a pointer: always-on
  context (an AGENTS.md line) or a documented environment variable.
- **Contract** — "what exact request authenticates me, and what do I send?" A
  weak or local model can hold the credential *in hand* and still fail here,
  because it rebuilds the request from priors and gets an endpoint, parameter
  name, or credential field subtly wrong.

Contract skills target the second failure. The rule of thumb:

> **Push everything exact into a script; let the skill be a map to it.**
> A bundled `scripts/<service>.sh <verb>` is something even a small model can
> run and report. Prose describing a request is something it will reconstruct
> wrong.

## How to use this skill

| Your task involves... | Read this file first | Why |
|----------------------|---------------------|-----|
| Writing a new service contract | [`patterns/author-a-contract.md`](patterns/author-a-contract.md) | End-to-end authoring steps |
| Designing for weak/local models | [`patterns/design-for-weak-models.md`](patterns/design-for-weak-models.md) | Determinism, triggering, progressive disclosure |
| Testing a contract against a model | [`patterns/evaluate-against-a-model.md`](patterns/evaluate-against-a-model.md) | Eval loop and regression suite |
| The canonical file layout | [`references/contract-anatomy.md`](references/contract-anatomy.md) | What belongs in which file |
| Portability and secret hygiene | [`references/portability-and-hygiene.md`](references/portability-and-hygiene.md) | Placeholders, env config, public-repo safety |
| Scaffolding a new contract | [`scripts/new-service-contract.sh`](scripts/new-service-contract.sh) | Generates a placeholder skeleton |

## Non-negotiables

- **No hardcoded environment.** Refer to `<base-url>`, `<service-host>`,
  `<credential>`, `<vault>` — never a real host, IP, account, or personal path.
  Resolve them from environment variables documented in the skill.
- **Scripts do the exact work.** The deterministic request lives in
  `scripts/`, not in prose the model must re-derive.
- **Never echo secrets.** Do not print resolved credential values, and do not
  enable shell tracing around them.
- **One service (or one tight capability) per contract.** Broad "all the
  services" skills mis-route on weak models.

## Common gotchas for contract authors

- The obvious credential field is not always the working one. Capture the field
  that *actually* authenticates, and say so explicitly.
- Endpoint and parameter names drift from intuition (e.g. a login path that
  differs from the auth path, or a parameter spelled unexpectedly). Pin the
  exact strings.
- State what *failure* looks like (status code, error shape) so the model can
  tell "wrong credential" from "wrong request".
- Keep the SKILL.md hot path self-contained. Do not force a weak model to
  choose among many reference files to complete the common case.

## Safety

Read verbs are safe. Write or destructive verbs in a contract must require an
explicit user decision and should be separated from read verbs so a model does
not trigger them by accident.
