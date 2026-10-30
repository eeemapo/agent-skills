# Thinking / reasoning modes

Reasoning models spend tokens before they answer. That is the whole failure mode:

> `finish_reason: "length"`, `content: ""`, and the budget consumed inside
> `reasoning_content`. The model is fine; the request asked for an essay of
> deliberation and no answer.

Three places can control it, in increasing specificity. Use the **lowest** one
that solves the problem.

## 1. The model's own template (what switches exist)

Inspect the GGUF first — the template tells you which control the model honours:

    python3 scripts/gguf-inspect.py <file>.gguf | grep chat_template
    # … mentions enable_thinking, reasoning_effort   → both knobs exist
    # … no thinking controls                          → nothing to turn off

Do not assume a model accepts both. A template that never reads
`reasoning_effort` silently ignores it.

## 2. Server default, set in the stanza

llama.cpp (GGUF stanzas):

    --jinja                                   # required, or templates are ignored
    --chat-template-kwargs '{"reasoning_effort":"xhigh"}'   # or enable_thinking:false
    --reasoning-preserve                      # keep reasoning across turns

vLLM (sibling-container stanzas): the parser is a server flag, and the template
kwargs may be asserted per request instead —

    --reasoning-parser <family>               # route thoughts out of `content`

A server default is right when *every* client of that model wants the same
behaviour. It is wrong when one client needs raw speed and another needs depth.

## 3. Per request (the right lever most of the time)

The OpenAI-compatible body carries it, and it passes through llama-swap and
LiteLLM untouched:

    {"model": "...", "messages": [...], "max_tokens": 256,
     "chat_template_kwargs": {"enable_thinking": false}}

    {"model": "...", "messages": [...], "max_tokens": 256,
     "reasoning_effort": "none"}          # none | minimal | low | medium | high

Notes:

- **LiteLLM only forwards these if it is configured to.** Unknown parameters are
  dropped when `drop_params` is on (default); the `ai` stack sets
  `drop_params: false` precisely so `chat_template_kwargs` survives.
- **Anthropic-style `/v1/messages`** carries the same intent as a `thinking`
  block; LiteLLM maps it onto the template kwargs.
- Where the answer lands: reasoning text in `reasoning_content`, the answer in
  `content`. A client that reads only `content` looks empty when the budget ran out.

## 4. Force it at the proxy (last resort)

llama-swap can rewrite request params per model:

    filters:
      stripParams: "max_tokens"      # remove something the client sends
      setParams:
        max_tokens: 32768            # …or pin it
      # setParamsByID: { <id>: { max_tokens: 8192 } }

Useful to cap a model that a client keeps truncating, or to strip a parameter the
backend rejects. It applies to **every** client of that stanza, so it is a blunt
instrument — prefer the request.

## Probe instead of guessing

One cheap request tells you where the tokens went:

    curl … -d '{"messages":[{"role":"user","content":"hi"}],"max_tokens":16}' | jq '.usage, .choices[0].finish_reason'

- `completion_tokens` ≈ `max_tokens` with empty `content` → thinking ate it.
- `reasoning_tokens` in `usage.completion_tokens_details` when the backend reports it.

| Symptom | Fix |
|---|---|
| empty `content`, `finish_reason: length` | `enable_thinking: false`, `reasoning_effort: none`, or a larger `max_tokens` |
| control appears to do nothing | the template does not read that key — check the inspect output |
| works at `ai.` but not direct to the node | LiteLLM dropped the param (or a llama-swap `filters` stripped it) |
| thinking text shows up in `content` | no reasoning parser on a vLLM backend; llama.cpp needs `--jinja` |
| multi-turn loses earlier reasoning | `--reasoning-preserve` is not set (deliberate on some models) |

## Don't

- Don't set a server-wide `enable_thinking: false` to make one benchmark faster;
  it silently degrades every other client of that model.
- Don't raise `max_tokens` to "fix" empty content without checking whether the
  client asked for reasoning in the first place.
