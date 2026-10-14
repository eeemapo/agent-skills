# Evaluating a contract against a model

A contract skill is only as good as the weakest model you intend to run it on.
Measure — do not assume.

## The loop

1. Write or edit the contract skill.
2. Give a **target model** the *bare* task, with no hints and no mention of the
   skill: for example, "authenticate to <the service> and report the account
   identity".
3. Observe: did it succeed? In how many turns or tool calls? Where did it
   stall?
4. Fix the skill — usually the Gotchas or the description — not the model.
5. Repeat until the bare task passes in a small, stable number of turns.

## Running the eval

Spawn a child agent on the chosen model with a self-contained task, then inspect
its transcript afterward. Keep the task realistic and bare; the whole point is
that the model discovers the contract.

Record, per run:

- outcome (pass or fail) and the final answer;
- turns and tool calls;
- the first wrong assumption (the stall point);
- whether any secret value appeared in the transcript.

## Turn count is the signal

A contract that works but takes many exploratory turns is not done — it is
missing a gotcha or a scripted verb. The target is "run one command, report":
single-digit turns.

## Keep a regression suite

- One assertion per capability (`auth`, `read`, `act`).
- Pin the model you intend to support.
- Re-run after any skill edit.
- Treat the suite as the gate for "is this model ready to drive this task?".

## Hygiene during eval

Check the transcript for leaked values and for hardcoded environment specifics.
An eval that passes by echoing a secret is a failure.
