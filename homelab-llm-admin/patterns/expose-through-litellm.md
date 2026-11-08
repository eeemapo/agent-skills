# Expose a model through LiteLLM (`ai.armadillo-hops.ts.net`)

> **Example ids in this file are illustrative.** No model named here is
> guaranteed to exist right now — stanzas get renamed and retired. The live
> roster is `scripts/fleet-status.sh` (or the node's own `/v1/models`). Read the
> shapes, substitute the real ids.

Layer 2. A model served by `lax` or `phx` is **not** reachable at the front door
until it has a `model_list` entry. This is the most common "the model exists but
I get 404" case.

## Where the file is

    mco:/opt/docker/deploy/ai/config/litellm/config.yaml   ← live, the bind source
    container: /app/config/config.yaml                      ← bind mount

The deploy tree is the stack's git checkout, so edit there and commit. There is
**no** orchestration plane to deploy through — Komodo was decommissioned
2026-11-02, which is also why the file can live in the checkout.

Verify the bind before debugging anything: `docker inspect ai-litellm-1` must
show `/opt/docker/deploy/ai/config/litellm → /app/config`. A `/stackData/...`
copy is a pre-migration leftover — editing it changes nothing.

## Step 1 — add the entry

Id convention: `<node>/<model-id>` where `<model-id>` is the llama-swap stanza's
own name (not its alias).

```yaml
- model_name: phx/Qwen3.8-27B-vLLM
  litellm_params:
    model: openai/Qwen3.8-27B-vLLM
    api_base: https://llama-swap-phx.armadillo-hops.ts.net/v1
    api_key: os.environ/LLAMA_SWAP_PHX_KEY
```

- `api_base` always ends in `/v1` and points at the **node**, never at `ai.` —
  a self-reference is a loop.
- The key comes from the environment (injected at deploy by the stack's
  `op run` wrapper). Never inline a key here.
- Optional per-model knobs: `rpm`/`tpm`, `max_budget`, `model_info.max_tokens`,
  `timeout`. Keep them out unless asked.

## Step 2 — hot reload (no restart)

The container runs `--reload`; `watchfiles` is installed into
`PYTHONPATH=/watchfiles` by the stack's `init` service, so uvicorn uses inotify
and watches `/app/config/config.yaml`.

    ssh mco
    cd /opt/docker/deploy/ai
    cp -a config/litellm/config.yaml /tmp/litellm.yaml.bak
    # edit config/litellm/config.yaml, then git commit -am "litellm: <what>"
    # edit in place (sed -i, ed, cat >) — see the note below
    docker logs --tail 20 ai-litellm-1 | grep -i "WatchFiles detected"

The checkout and its `config/litellm/` directory are `sysops`-owned, so
in-place edits, backups beside the file and write-then-rename saves all work. If
ownership ever regresses to `root:root`, a rename-saving editor fails there or
leaves a root-owned file; `cd /opt/docker/deploy/ai && unfuck` (host alias, needs
sudo) restores it, then set config files back to `644`.

A saved edit logs `WatchFiles detected changes in 'config/config.yaml'. Reloading…`
and the worker comes back in ~1–2 s. **In-flight requests can drop** — reload is
an in-place worker restart, not a rolling deploy.

If it does **not** reload:

| Check | Meaning |
|---|---|
| `Started reloader process [1] using StatReload` | `watchfiles` missing from `PYTHONPATH`; fix the `init` service, not the config |
| CPU pegged ~100% | same cause — StatReload stat-scans every `*.py` under `/app` |
| no reload line at all | file edited in the wrong place (the stale `/stackData` copy, not `/opt/docker/deploy/ai/config/litellm/`) |
| reload line, but the model is unchanged | the edit was reverted by a write-then-rename, or landed in a stale copy |

## Step 3 — virtual-key scoping

Keys live in LiteLLM's Postgres (`store_model_in_db: true`), not in the YAML.
Aliases in use: `pi`, `work`, `public` (the OpenWebUI key is parked).

- `models: []` → the key reaches **every** model (all but `public`).
- `public` carries an **explicit list**, so a newly added model is invisible to
  it until added:

```bash
# inside the container (no curl in the image)
docker exec ai-litellm-1 /app/.venv/bin/python -c "
import os,json,urllib.request
mk=os.environ['LITELLM_MASTER_KEY']
r=urllib.request.Request('http://127.0.0.1:4000/key/list?return_full_object=true',
                         headers={'Authorization':'Bearer '+mk})
for k in json.load(urllib.request.urlopen(r,timeout=20))['keys']:
    print(k.get('key_alias'), k.get('models'))"
```

Update a key's list with `POST /key/update` (`key=<alias-or-key>`,
`models=[...]`) or the admin UI at `https://ai.armadillo-hops.ts.net/ui/`.
Both take effect immediately — no reload needed.

Symptom → cause:

- **401** `Authentication Error, No api key passed` — client sent no key.
- **403/400** mentioning the model — key exists but does not scope the model.
- **404 / model not found** — no `model_list` entry (step 1).

## Step 4 — verify end to end

    KEY=$(vault: litellm-ops → pi)     # never echo it
    curl -s https://ai.armadillo-hops.ts.net/v1/models \
      -H "Authorization: Bearer $KEY" | jq -r '.data[].id' | grep -i qwen

    curl -s https://ai.armadillo-hops.ts.net/v1/chat/completions \
      -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
      -d '{"model":"phx/Qwen3.8-27B-vLLM","messages":[{"role":"user","content":"hi"}],"max_tokens":16}'

A model in `/v1/models` proves only that LiteLLM parsed the entry. The chat
completion is the real test — it makes LiteLLM call the node, which is where a
wrong `api_base`, dead node or non-starting backend shows up.

## Gotchas

- **DB overlay wins.** `general_settings`, `router_settings`, `litellm_settings`
  and `environment_variables` are overlaid from Postgres on startup and on every
  reload. Editing those keys in the YAML does nothing while a DB row exists;
  clear the DB row first or change it in the UI.
- **YAML models are file-owned** — they appear in the UI but cannot be edited
  there. Models added via the UI/API live in the DB and vanish from the file's
  authority. Pick one home per model; the repo convention is YAML.
- **`proxy_config_reload_interval_seconds: 30`** only affects DB-backed changes.
- Two entries may share a `model_name` for load-balancing/failover; that is a
  deliberate pattern, not a duplicate.
