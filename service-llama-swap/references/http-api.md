# llama-swap HTTP API — wire catalog

Base: `$LLAMA_SWAP_URL`. Auth: `Authorization: Bearer <KEY>` (an `X-Api-Key`
header also works).

| Verb | Method | Path |
|------|--------|------|
| health | GET | `/health` |
| version | GET | `/api/version` |
| models | GET | `/v1/models` |
| running | GET | `/running` |
| profiles | GET | `/api/profiles` |
| logs | GET | `/logs` (stream) |
| unload one | POST | `/api/models/unload/{model_id}` |
| unload all | POST | `/api/models/unload` |

## Inference surface (proxied to the upstream server)

- `POST /v1/chat/completions`, `/v1/completions`, `/v1/responses`
- `POST /v1/embeddings`, `/v1/audio/speech`, `/v1/audio/transcriptions`
- `POST /v1/images/generations`, `/v1/images/edits`
- `POST /v1/messages` (Anthropic-compatible)
- `GET /v1/models` / `/models`
- `GET /props?model={id}`
- `POST /v1/rerank`, `/infill`, `/completion`

## Response shape

`/v1/models`:

    {"data":[{"id":"GLM-OCR","object":"model","owned_by":"llama-swap",
              "architecture":{...},"capabilities":{"vision":true},
              "context_length":8192,"context_window":8192}, ...]}

`/running`:

    {"running":[{"model":"audiocpp","state":"ready","cmd":"docker run ..."}]}

`/api/version`:

    {"build_date":"2026-10-03T06:29:19Z","commit":"079c35a","version":"v262"}

## Errors

| Code | Meaning |
|------|---------|
| 401 | missing/invalid key |
| 404 | unknown model or path |
| 405 | wrong method (e.g. POST to `/unload` — the unload paths live under `/api/models/`) |
