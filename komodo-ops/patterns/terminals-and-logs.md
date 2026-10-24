# Logs and Shells

**Use when** you need to read container/stack logs, or you are tempted to run a shell command
on a managed server or inside a container.

## Logs (the normal path)

```
komodo_container_logs        { server: "prod-01", container: "web", tail: 200, timestamps: false }
komodo_container_search_logs { server: "prod-01", container: "web", query: "ERROR", tail: 1000, caseSensitive: false }
komodo_build_logs            { update_id: "<update-id>" }
komodo_update_info           { id: "<update-id>" }        # stage-by-stage stdout/stderr of any execution
```

- `komodo_container_logs` tails recent output (`tail` default 100).
- `komodo_container_search_logs` retrieves `tail` lines (default 1000) and filters
  client-side. Plain text, not a regex.
- `komodo_build_logs` / `komodo_update_info` are how you read what a deploy/build actually
  did — the `Update.logs[]` entries are per **stage** (`Deploy Container`, `Clone Repo`,
  `Diff compose files`, …), each with `stdout`/`stderr`/`success`.

**Stack, deployment, and swarm-service logs have no typed tool.** Use `komodo_raw`:

```
komodo_raw { op: "GetStackLog",        args: { stack: "my-stack", services: [], tail: 100 } }
komodo_raw { op: "SearchStackLog",     args: { stack: "my-stack", terms: ["ERROR"], combinator: "And" } }
komodo_raw { op: "GetDeploymentLog",   args: { deployment: "web", tail: 100 } }
komodo_raw { op: "GetSwarmServiceLog", args: { service: "web", tail: 100 } }
```

Log responses are `Log { stage, command, stdout, stderr, success, start_ts, end_ts }`.
`tail` defaults ~50 and caps at 5000; `terms` + `combinator` (`And`/`Or`) + `invert` drive
the search variants.

## Shells: not through this extension

**`komodo_exec` exists in the extension but is excluded in this deployment**
(`"excludedTools": ["komodo_exec"]`), and `komodo_raw` is the only other route to a host
shell. Reach a server over **SSH** (or the operator's `op` path) instead.

The reason, in one line: **the Komodo API key is a service credential, not a shell
gateway.** Host shells have a different blast radius and a different audit trail, so they
stay on the host's own access path.

If you find yourself wanting `komodo_exec`, stop and ask the user how they want the host
touched. Do not invent a workaround with `RunStackService` or a terminal session.

## The terminal namespace (raw, deliberately off the normal path)

Core does expose terminals — a `TerminalTarget` is one of:

```jsonc
{ "type": "Server",     "params": { "server": "prod-01" } }
{ "type": "Container",  "params": { "server": "prod-01", "container": "web" } }
{ "type": "Stack",      "params": { "stack": "my-stack", "service": null } }
{ "type": "Deployment", "params": { "deployment": "web" } }
```

`komodo_help { ns: "terminals" }` lists the five operations
(`CreateTerminal`, `ListTerminals`, `DeleteTerminal`, `DeleteAllTerminals`,
`BatchDeleteAllTerminals`). Executing a command additionally uses `POST /terminal/execute`,
which returns a **raw PTY byte stream, not JSON** — one more reason this is a debugging path
and not the way an agent works:

- It needs `Read` + the `Terminal` specific permission on the target.
- Sessions are created first (`CreateTerminal`, named, persistent) unless you pass `init`.
- Command execution has no `Update`, no stage logs, and no polling — output parsing is
  yours.

These ops are risk-classed `terminal` and gated (in a deployment where the gate is on). Here
the gate is off, so treat them as user-authorised-only.

## Permissions

| Need | Requires |
|------|----------|
| Read logs | `Logs` specific permission |
| Read a container's detail | `Inspect` |
| Use a terminal | `Terminal` (and `Attach` to attach) |

Check with `komodo_whoami`, or a scoped `GetPermission` — see
[`authenticate.md`](authenticate.md).

## Key rules

- Prefer `komodo_container_logs` / `_search_logs`; drop to raw only for stack/deployment/
  swarm logs.
- Read an execution's own stage logs (`komodo_update_info`) before blaming a service.
- Do not use Komodo for host shells. SSH is the path; ask the user.
- Terminal output is bytes, never a JSON `Log` — never parse it as one.
