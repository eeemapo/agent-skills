# Inspect a GGUF before you trust it

Weights are opaque until you read them, and every failure mode below looks the
same from the API: the model "just doesn't load".

`scripts/gguf-inspect.py` reads the header, metadata and tensor table only — no
weight data, no dependencies (stdlib only), so it is instant on a 60 GB file and
works on any host or inside a container.

    python3 scripts/gguf-inspect.py /opt/ai/<tree>/models/<name>/<file>.gguf

Use it **before** wiring a stanza, and again after any large download.

## What to read, and what it decides

| Field | Why it matters |
|---|---|
| `arch` | the engine must know it. llama.cpp is permissive; a specialised engine is not — Strata only runs `qwen4exp`, `qwen35moe`, `deepseek41` and will reject anything else |
| `context_length` | the file's native ceiling. The stanza's `--ctx-size` / `CONTEXT` must be ≤ this, and `capabilities.context` should match the stanza, not the file |
| `general.file_type` + tensor dtypes | the real quant. A label in a repo name is marketing; the tensor table is fact |
| `chat_template` | missing template ⇒ `--jinja` and every reasoning control are dead. The hint list tells you *which* switch the model exposes (`enable_thinking` vs `reasoning_effort`) |
| `split` | shard N of M ⇒ the stanza needs **every** shard in one directory |
| `tokenizer` | mismatched tokenizer family explains odd token counts, not bad answers |
| parameter count + B/param | sanity-check the size against the download you expected |

## Red flags

| Symptom in the output | What it means |
|---|---|
| `arch` not supported by the chosen engine | pick llama.cpp, or a different model — not a different flag |
| `chat_template MISSING` | reasoning/thinking controls cannot work; tool-calling templates usually depend on it too |
| `split … shard 1 of 3` | verify all three files are present and in the same directory |
| `context_length` lower than the stanza's `--ctx-size` | the stanza is asking for context the file was not trained for |
| no `mmproj` file beside a vision model | `capabilities.in: [image]` is a lie; downloads the projector separately |
| `unexpected end of file` | truncated download — re-fetch, don't retry the load |
| dtype mostly `F32`/`F16` where you expected a small quant | you grabbed the wrong file from the repo |

## Limits

- It validates **structure**, not correctness: a well-formed file with bad weights
  inspects cleanly. If the repo publishes a SHA-256, compare it.
- Split shards each report their own tensor subset; the parameter estimate is per
  shard, not for the whole model.
- `general.size_label` is whatever the uploader wrote (often `512x56B`-style
  active-parameter notation) — treat it as a hint, not a measurement.
