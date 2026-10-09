# Use the pi-komodo extension

**Use when** you need to administer Komodo. The supported interface is the **pi-komodo**
extension — native in-process `komodo_*` tools (a fork of `komodo-mcp-server`, no MCP
transport, no subprocess, no HTTP client, no bundled scripts). This skill documents *how*
to drive it; [`references/http-contract.md`](http-contract.md) remains for raw-HTTP
debugging and non-pi clients.

## Credentials

Credentials come from pi's **`auth.json`** — the `komodo` entry in
`$PI_CODING_AGENT_DIR/auth.json` (default `~/.pi/agent/auth.json`). That is the single
origin; there are **no environment variables**. It must be a valid pi credential object
(`type: "api_key"`), with the Komodo extras alongside:

```json
{
  "komodo": {
    "type": "api_key",
    "key": "!/home/sysops/.pi/agent/op-read.sh op://HL-OPS/komodo-key/credential",
    "apiSecret": "!/home/sysops/.pi/agent/op-read.sh op://HL-OPS/komodo-key/secret",
    "url": "https://komodo.armadillo-hops.ts.net"
  }
}
```

Any value may be a literal, a `$NAME`/`${NAME}` reference, or a leading **`!command`**
whose trimmed stdout is used — so secrets stay in 1Password (via Connect) and never land
on disk. Values are resolved **once per pi process**: **restart pi** after rotating a key.
(`type`/`key` must be present or pi itself rejects the file; extra keys such as
`url`/`apiSecret` are ignored by pi and read by the extension.)

Never commit a credential; reference it (`op://…`, `$NAME`) instead.

## Behaviour configuration (settings.json)

Behaviour is a **`komodo` block in `~/.pi/agent/settings.json`**, read via
`pi.getSettings()` — no environment variables. All keys optional; absent keys keep
defaults:

```json
{ "komodo": {
    "exposure": "direct",
    "compact": false,
    "assumeYes": false,
    "confirmDestructive": true,
    "confirmFallback": "deny",
    "confirmRemember": true,
    "confirmTimeout": "5m",
    "allowedCategories": [],
    "excludedCategories": [],
    "excludedTools": ["komodo_exec"],
    "resourceTtlInfo": "15m",
    "resourceTtlLogs": "2m",
    "resourceMaxEntries": 1000,
    "apiTimeout": "30s"
} }
```

| Key | Meaning |
|---|---|
| `exposure` | `direct` (default) · `model-only` · `codemode` · `deferred` · `hidden` |
| `compact` | merge the tool set into a small resource+verb facade (defaults on for Fabric child agents) |
| `assumeYes` | auto-approve destructive confirmations (no dialog) |
| `confirmDestructive` | `false` disables the destructive-op confirmation gate entirely |
| `confirmFallback` | `allow` \| `deny` — behaviour when the client can't prompt (default `deny`) |
| `confirmRemember` | remember an accepted confirmation for the session (default `true`) |
| `confirmTimeout` | how long to wait for a confirmation (default `5m`) |
| `allowedCategories` / `excludedCategories` / `excludedTools` | prune the tool surface (e.g. exclude `komodo_exec`) |
| `resourceTtlInfo` / `resourceTtlLogs` / `resourceMaxEntries` / `apiTimeout` | registry TTLs + API timeout |

`PI_FABRIC_AGENT_NAME` (set by Fabric for child agents) is a runtime marker, not config —
it defaults `compact`/`assumeYes` on for headless children.

## Tool surface

Names are `komodo_<resource>_<verb>`:

| Group | Tools |
|---|---|
| Servers | `komodo_server_list` · `_info` · `_stats` · `_action` · `_apply` · `_delete` |
| Swarms | `komodo_swarm_list` · `_info` · `_apply` · `_delete` · `_action` · `komodo_swarm_nodes_list` · `komodo_swarm_services_list` |
| Stacks | `komodo_stack_list` · `_info` · `_action` (deploy/start/stop/restart/pause/destroy/prune) · `_apply` · `_delete` |
| Deployments | `komodo_deployment_list` · `_info` · `_action` · `_apply` · `_delete` |
| Builds / builders / repos | `komodo_build_list` · `_info` · `_action` · `_logs` · `_apply` · `_delete`; `komodo_builder_*`; `komodo_repo_*` |
| Containers | `komodo_container_list` · `_inspect` · `_logs` · `_search_logs` · `_action` |
| Docker objects | `komodo_docker_image_*` · `komodo_docker_network_*` · `komodo_docker_volume_*` |
| Procedures / actions / syncs | `komodo_procedure_*` · `komodo_action_*` · `komodo_resource_sync_*` |
| TOML export | `komodo_toml_export_all` · `komodo_toml_export_resources` |
| Users / vars / tags / alerters | `komodo_user_*` (incl. `komodo_user_create_api_key`, `komodo_user_list_api_keys`) · `komodo_variable_*` · `komodo_tag_*` · `komodo_alerter_*` |
| Utility | `komodo_health_check` (connection state) · `komodo_exec` (arbitrary shell on a host — **excluded in this deployment**, see Safety) |

Resource **reads** use `_list`/`_info`; **writes** use `_apply`/`_delete`; **actions** use
`_action` and return the finished `Update`. Paging/query params: `limit: 0` means all.

## Safety

- Destructive actions (`*_delete`, `destroy`, `prune`, `_action` runs) require
  confirmation via pi's dialog. Headless there is no dialog → **denied** unless
  `confirmFallback: "allow"` (settings.json).
- **This deployment:** `komodo_exec` is dropped (`"excludedTools": ["komodo_exec"]`) and
  the destructive prompt is off (`"confirmDestructive": false`) in
  `~/.pi/agent/settings.json`. Reach a host shell over **SSH / the `op` path**, not
  Komodo — the API key is a service credential, not a shell gateway. Settings are read at
  extension load; `pi.getSettings()` changes apply on the next pi restart.
- Resolve the exact target set (`*_list`) before a batch/pattern action; `PruneSystem`
  (volumes) and `DestroyStack` have the highest blast radius.
- Confirm intent before destroy/prune/delete/stop, and never echo `K_…`/`S_…`.

## Verify

`komodo_health_check` → `configured: true, healthy: true` with the Core version. If it
reports *not configured*, the credentials did not resolve (stale auth.json values, a
failed `!command`, or a 401 that dropped the connection) — re-check the `op://` refs and
restart pi.
