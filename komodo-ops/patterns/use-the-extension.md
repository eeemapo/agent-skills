# The pi-komodo Extension

**Use when** you need to know how the Komodo tools are wired: where credentials come from,
which settings shape the surface, what the confirmation gate does, or how to verify the
connection.

Short version: **credentials from pi's `auth.json`, behaviour from a `komodo` block in
pi's `settings.json`, everything in-process.** There is no MCP transport, no subprocess, and
no HTTP client to write.

## Two layers over one surface

| Layer | Tools | Notes |
|-------|-------|-------|
| Typed | 91 `komodo_<domain>_<verb>` tools (`komodo_exec` is registered but excluded in this deployment) | the common path; `_action` polls the `Update` to completion |
| Raw | `komodo_help` + `komodo_raw` | browse and call any of the 334 Core operations by name |

Reads are `_list`/`_info`; writes are `_apply`/`_delete`; executions are `_action`
(actions) or `_action action="run"` (builds, repos, procedures, actions, syncs).

## Credentials (`auth.json`)

Pi's agent config — `$PI_CODING_AGENT_DIR/auth.json` (default `~/.pi/agent/auth.json`) —
holds a **`komodo`** entry. This is the single origin for the `pi-auth` key source; values
may be literals, `$NAME` references, or a leading `!command` whose trimmed stdout is used
(so the secret can stay in 1Password and never land on disk):

```json
{
  "komodo": {
    "type": "api_key",
    "apiKey": "!/path/to/op-read.sh op://HL-INF/komodo-key/credential",
    "url": "https://komodo.example.ts.net"
  }
}
```

| Field (aliases) | Meaning |
|---|---|
| `apiKey` (`api_key`, `key`) | the `K_…` key. A single value holding `K_<id>:<secret>` is split automatically (an explicit `apiSecret` always wins) |
| `apiSecret` (`api_secret`, `secret`) | the `S_…` half, when stored separately |
| `jwtToken` (`jwt`) | a user JWT instead of a key pair |
| `username` + `password` | login credentials |
| `url` | Core base URL (falls back to `komodo.baseUrl` in settings) |

`type` and `key`/`apiKey` must be present or pi itself rejects the file. **`auth.json`
wins** over the environment fallback: `KOMODO_URL`, `KOMODO_API_KEY`, `KOMODO_API_SECRET`,
`KOMODO_JWT_TOKEN`, `KOMODO_USERNAME`, `KOMODO_PASSWORD` and their `*_FILE` Docker-secret
variants.

Never commit or echo a credential; reference it (`op://…`, `$NAME`) instead.

## Session keys — not an ambient credential

The extension deliberately holds **no ambient credential**. It resolves a *session key*:

- `/komodo status | load ops|srv|inf | clear` — human-gated, masked prompt. The key is held
  **in memory for the session only** and cleared at shutdown. The model has no load/clear
  path, so it can neither escalate nor strand itself.
- `komodo.autoLoad` in settings loads the ambient `auth.json` key at session start with no
  prompt (`"ops"` labels it `komodo:ops`; the label is cosmetic — Komodo enforces the real
  authority of the account behind the key).
- Key sources are generic (`command`, `file`, `env`, `inline`, `pi-auth`), so the extension
  has no dependency on any particular secret provider.

Inspect with `komodo_auth` (source, fingerprint, loaded time, permission summary) — see
[`authenticate.md`](authenticate.md).

## Behaviour (`settings.json`)

A **`komodo` block** in `$PI_CODING_AGENT_DIR/settings.json` (default
`~/.pi/agent/settings.json`), read directly at extension load — project-level settings and
runtime overrides are not merged. All keys optional; absent keys keep defaults:

```json
{ "komodo": {
    "exposure": "direct",
    "compact": false,
    "autoLoad": "ops",
    "assumeYes": false,
    "confirmDestructive": true,
    "confirmFallback": "deny",
    "excludedTools": ["komodo_exec"],
    "baseUrl": "https://komodo.example.ts.net"
} }
```

| Key | Meaning |
|---|---|
| `exposure` | `direct` (default) · `model-only` · `codemode` · `deferred` · `hidden` |
| `compact` | collapse the surface into a small resource+verb facade (default off) |
| `autoLoad` | `true` \| `"ops"` \| `"srv"` \| `"inf"` — auto-load the ambient key at session start |
| `assumeYes` | pre-authorise destructive confirmations (no dialog) |
| `confirmDestructive` | `false` disables the confirmation gate entirely |
| `confirmFallback` | `allow` \| `deny` (default) — what happens when the client cannot prompt |
| `confirmTimeout` / `confirmRemember` | confirmation wait (default `5m`) and per-session memo |
| `allowedCategories` / `excludedCategories` / `excludedTools` | prune the tool surface by category or tool name |
| `apiTimeout` | per-request timeout (default `30s`) |
| `baseUrl` | Core URL when `auth.json` carries none |

Env equivalents exist and override: `KOMODO_*` (e.g. `KOMODO_CONFIRM_DESTRUCTIVE`,
`KOMODO_TOOLS_*`, `KOMODO_SECRET_SCRUB_*`, `KOMODO_API_TIMEOUT_MS`). Suffix `*_FILE` reads a
Docker secret.

**Prune by category**, which is more durable than by tool name: `config`, `server`, `swarm`,
`container`, `terminal`, `stack`, `deployment`, `build`, `repo`, `procedure`, `action`,
`alerter`, `user`, `variable`, `resource_sync`, `update`, `docker`, `builder`, `tag`, `toml`.

## The confirmation gate

Destructive actions (deletes, destroys, prunes, and raw operations whose risk class is
`destructive`, `control-plane`, `terminal`, or `admin`) pass through
`requireDestructiveConfirmation`, which **short-circuits on the first line**:

```
if (!config.KOMODO_CONFIRM_DESTRUCTIVE) return;
```

So the setting is a kill switch, and the fallback only matters once the gate is on:

| `confirmDestructive` | Behaviour |
|---|---|
| `true` (default) | prompts via pi's dialog; headless applies `confirmFallback` (`deny` fails closed, `allow` executes with an audit warning) |
| `false` | **no prompt, no fail-closed** — every destructive call proceeds |

**This deployment runs `confirmDestructive: false` plus `excludedTools: ["komodo_exec"]`**,
so nothing prompts and nothing protects you. The safety rules in
[`run-executions.md`](run-executions.md) and `SKILL.md` are the only guardrail: confirm
intent with the user first.

## Redaction

Tool output is scrubbed of secret-shaped values at the pi tool boundary (on by default;
`KOMODO_SECRET_SCRUB_ENABLED=false` disables). `KOMODO_SECRET_SCRUB_KEYS` adds extra
key-name fragments to redact; `KOMODO_SECRET_SCRUB_ALLOW_KEYS` exempts exact keys. Scrubbing
is best-effort — it is not a licence to print credentials.

## Verify the connection

| Tool | Needs a key? | Reports |
|---|---|---|
| `komodo_health_check` | no | `configured`, `healthy`, Core version, extension version |
| `komodo_auth` | no (status only) | source, identity, fingerprint, loaded time, permissions |
| `komodo_whoami` | yes | effective identity + per-resource-type permission summary from Komodo |

If `komodo_health_check` reports *not configured*, the credentials did not resolve (stale
`auth.json`, a failed `!command`, or a bad URL) — or the session simply has **no key
loaded**, which is the normal keyless state. Distinguish the two with `komodo_auth`: if it
says no key, ask the operator to run `/komodo`.
