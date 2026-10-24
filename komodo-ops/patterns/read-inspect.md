# Read and Inspect

**Use when** you need to see what Core manages, find exact resource ids/names, check live
state, read logs, or query server stats.

Every read is a typed `_list` or `_info` tool. Only for what has no typed tool do you reach
`komodo_raw` — see [`raw-operations.md`](raw-operations.md).

## Resource vocabulary → tools

| Kind | What it is | Read with |
|------|-----------|-----------|
| Server | machine running Periphery | `komodo_server_list` · `_info` · `_stats` |
| Container | a Docker container on a server | `komodo_container_list` · `_inspect` · `_logs` · `_search_logs` |
| Docker objects | images, networks, volumes on a server | `komodo_docker_image_list` · `_inspect` · `_history`; `komodo_docker_network_list` · `_inspect`; `komodo_docker_volume_list` · `_inspect` |
| Stack | a `docker compose` project | `komodo_stack_list` · `_info` |
| Deployment | a single-container definition | `komodo_deployment_list` · `_info` |
| Swarm | a Docker Swarm cluster | `komodo_swarm_list` · `_info` · `komodo_swarm_nodes_list` · `komodo_swarm_services_list` |
| Build / Repo / Builder | image build pipeline | `komodo_build_list` · `_info` · `_logs`; `komodo_repo_list` · `_info`; `komodo_builder_list` · `_info` |
| Procedure / Action / Sync | automation recipes | `komodo_procedure_list` · `_info`; `komodo_action_list` · `_info`; `komodo_resource_sync_list` · `_info` |
| Alerter | notification sinks | `komodo_alerter_list` · `_info` |
| Variable / Tag | config primitives | `komodo_variable_list` · `_info`; `komodo_tag_list` · `_info` |
| Update | an execution run | `komodo_update_list` · `_info` |
| User / Group / Permission | access model (**raw only**) | `komodo_raw { op: "ListUsers" \| "FindUser" \| "ListUserGroups" \| "ListPermissions" … }` |
| Summaries / core info | dashboard counts, Core settings (**raw only**) | `komodo_raw { op: "GetStacksSummary" \| "GetCoreInfo" \| "GetVersion" … }` |

## List queries

Typed `_list` tools take the same query object as the API (`page_size`, `cursor`, plus
resource filters where the tool exposes them) and page through results for you. On
`komodo_raw` you drive the full list request yourself:

```
komodo_raw { op: "ListStacks", args: {
  query: { terms: ["prod"], tags: ["prod"], tag_behavior: "All" },
  limit: 0, sort_by: "State" } }
```

- `List*` returns lightweight list items; `ListFull*` returns complete configs.
- `Get*` fetches one resource by **id or name**.
- Query specifics (e.g. `StackQuerySpecifics.server_ids`, `swarm_ids`) require **ids**, not
  names.
- `limit: 0` means unlimited; otherwise paging defaults to Core's
  `default_pagination_limit` (default 30) and `page` is 0-based.
- Field meanings: [`../references/schemas-and-queries.md`](../references/schemas-and-queries.md).

## Containers across servers

```
komodo_container_list { server: "prod-01" }                 # containers on one server
komodo_container_inspect { server: "prod-01", container: "web" }
komodo_container_action { action: "restart", server: "prod-01", container: "web" }
```

The raw equivalents (`ListAllContainers` with `servers`/`state`/`terms` filters,
`GetContainersSummary`) are how you sweep **every** server at once — see the catalog in
[`../references/endpoint-catalog.md`](../references/endpoint-catalog.md).

## Logs

```
komodo_container_logs        { server, container, tail?, timestamps? }   # tail default 100
komodo_container_search_logs { server, container, query, tail?, caseSensitive? }
komodo_build_logs            { update_id }                               # per-stage build logs
```

Stack, deployment, and swarm-service logs have no typed tool — use `GetStackLog` /
`SearchStackLog`, `GetDeploymentLog` / `SearchDeploymentLog`, `GetSwarmServiceLog` /
`SearchSwarmServiceLog` through `komodo_raw`. Responses are
`Log { stage, command, stdout, stderr, success, start_ts, end_ts }`; `tail` defaults ~50 and
caps at 5000.

## State, stats, and action-in-progress

```
komodo_server_stats { server }        # live system stats
```

Raw-only: `GetServerState`, `GetSystemInformation`, `GetHistoricalServerStats`,
`ListSystemProcesses`, and `GetStackActionState` / `GetDeploymentActionState` — the last
returns booleans (`pulling`, `deploying`, `stopping`, …) and is how you check whether an
operation is still in flight before starting another.

## Updates

```
komodo_update_list { operation?, target_type?, target_id?, page_size?, cursor? }   # newest first
komodo_update_info { id }                                                          # full payload + stage logs
```

`komodo_update_list` is the audit trail of every execution (Deploy, RunBuild, RunSync, …).
`ListUpdates` via raw returns `{updates, next_page}` for older pages.

## Export to TOML

```
komodo_toml_export_all  { include_resources?, include_variables?, include_user_groups?, tags? }
komodo_toml_export_resources { targets: "Stack:web, Deployment:api" }
```

Useful for seeding a ResourceSync or diffing against a repo — secret values are redacted, so
the export is for inspection, not verbatim re-apply. See
[`resource-sync-toml.md`](resource-sync-toml.md).

## Workflow example

```
# 1) find the unhealthy prod stacks
komodo_stack_list { page_size: 100 }
# 2) inspect the one that is down
komodo_stack_info { stack: "my-stack" }
# 3) read the container log behind it
komodo_container_logs { server: "prod-01", container: "web", tail: 200 }
```

## Key rules

- Prefer a typed `_list`/`_info` tool; reach for `komodo_raw` only when none exists.
- Resolve names to **ids** before any write or batch action.
- `limit: 0` (raw) fetches everything; otherwise page deliberately.
- Prefer `Get*ActionState` over guessing whether an operation is still running.
- Do not read secrets: `ListSecrets` returns key **names**, and scrubbing is best-effort.
