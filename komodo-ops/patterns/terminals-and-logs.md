# Terminals and Logs

Use when: you need to run a shell command on a managed server or inside a container, keep a persistent session, or read logs.

## Terminal targets

A terminal is identified by a `TerminalTarget`:

```jsonc
{ "type": "Server",     "params": { "server": "prod-01" } }
{ "type": "Container",  "params": { "server": "prod-01", "container": "web" } }
{ "type": "Stack",      "params": { "stack": "my-stack", "service": null } }
{ "type": "Deployment", "params": { "deployment": "web" } }
```

## Create a named, persistent session

```jsonc
POST /write { "type": "CreateTerminal", "params": {
    "name": "deploy-shell",
    "target": {"type": "Server", "params": {"server": "prod-01"}},
    "command": "bash",             // optional; server default shell if omitted
    "mode": "exec",                // container targets: "exec" | "attach"
    "recreate": "Never"            // "Never" | "Always" | "DifferentCommand"
} }
```

Returns a `Terminal` (`name`, `target`, `command`, `stored_size_kb`, `created_at`). Sessions persist and retain history across disconnects. List them with `/read/ListTerminals`.

Delete with `DeleteTerminal` `{target, terminal}`, `DeleteAllTerminals` `{server}`, or `BatchDeleteAllTerminals` `{query}`.

## Execute a command (streamed output)

```http
POST /terminal/execute
{
  "target": {"type": "Server", "params": {"server": "prod-01"}},
  "terminal": "deploy-shell",
  "command": "df -h"
}
```

- The response body is a **raw byte stream of PTY output** (not JSON).
- Pass `init` instead of pre-creating a session to auto-create it:
  `"init": {"command": "bash", "recreate": "Never", "mode": "exec"}`.
- Requires `Read` + `Terminal` specific permission on the target.

```bash
curl -sS $CORE/terminal/execute \
  -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"target":{"type":"Server","params":{"server":"prod-01"}},"terminal":"deploy-shell","command":"uptime"}'
```

## Interactive sessions over websocket

The terminal websocket supports bidirectional I/O for full interactivity: send stdin bytes, and `TerminalResizeMessage {rows, cols}` when the client window changes. See `GET /ws` and the generated `/client/terminal.d.ts`. For most agent tasks, one-shot `/terminal/execute` is simpler and sufficient.

## Logs (read endpoints)

```jsonc
POST /read { "type": "GetContainerLog",    "params": {"server":"prod-01","container":"web","tail":200} }
POST /read { "type": "SearchContainerLog", "params": {"server":"prod-01","container":"web","terms":["ERROR"],"combinator":"And"} }
POST /read { "type": "GetStackLog",         "params": {"stack":"my-stack","services":[],"tail":100} }
POST /read { "type": "GetDeploymentLog",   "params": {"deployment":"web","tail":100} }
```

Responses are `Log { stage, command, stdout, stderr, success, start_ts, end_ts }`. Search endpoints support `terms`, `combinator` (`And`/`Or`), and `invert`. `tail` default ~50, max 5000.

## Permissions

Terminals require the `Terminal` specific permission; log reads require `Logs`; container inspect requires `Inspect`. See `patterns/authenticate.md` and `patterns/users-and-permissions.md`.

## Key rules

- `/terminal/execute` output is bytes, not a JSON `Log`. Parse/print it directly.
- `CreateTerminal` fails if a session of that name exists with a different command unless you set `recreate`.
- Container terminals need a disambiguated `server` when the container name appears on multiple servers (use `ListAllContainers` first).

## Workflow example

```bash
# run a quick command, then read the container log
curl -sS $CORE/terminal/execute -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"target":{"type":"Container","params":{"server":"prod-01","container":"web"}},"terminal":"probe","command":"env","init":{"command":"sh","recreate":"Never"}}'
curl -sS $CORE/read -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"GetContainerLog","params":{"server":"prod-01","container":"web","tail":100}}'
```
