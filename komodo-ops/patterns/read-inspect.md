# Read and Inspect

Use when: you need to see what a Core manages, find exact resource ids/names, check live state, read logs, or query server stats.

## Resource vocabulary

| Kind | What it is | Key read endpoints |
|------|-----------|--------------------|
| Server | Machine running Periphery | `ListServers`, `GetServer`, `GetServerState`, `GetPeripheryInformation` |
| Swarm | Docker Swarm cluster | `ListSwarms`, `InspectSwarm`, `ListSwarmNodes`, `ListSwarmServices` |
| Stack | `docker compose` project | `ListStacks`, `GetStack`, `ListStackServices`, `GetStackLog` |
| Deployment | Single container definition | `ListDeployments`, `GetDeployment`, `GetDeploymentLog` |
| Build / Repo / Builder | Image build pipeline | `ListBuilds`, `ListRepos`, `ListBuilders`, `ListBuildVersions` |
| Procedure / Action / Sync | Automation recipes | `ListProcedures`, `ListActions`, `ListResourceSyncs`, `ListSchedules` |
| Alerter / Alert | Notifications | `ListAlerters`, `ListAlerts`, `GetAlert` |
| Update | An execution run | `GetUpdate`, `ListUpdates` |
| User / Group / Permission | Access model | `ListUsers`, `FindUser`, `ListUserGroups`, `ListPermissions` |
| Variable / Tag / Provider | Config primitives | `ListVariables`, `ListTags`, `ListGitProviderAccounts` |

## Generic list request

```bash
curl -sS $CORE/read \
  -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{
    "type": "ListStacks",
    "params": {
      "query": {"terms": ["prod"], "tags": ["prod"], "tag_behavior": "All"},
      "limit": 0,
      "sort_by": "State"
    }
  }'
```

- `List*` returns lightweight list items; `ListFull*` returns complete configs.
- `Get*` fetches one resource by **id or name**.
- Query specifics (e.g. `StackQuerySpecifics.server_ids`, `swarm_ids`) require **ids**, not names.

## Containers across servers (Docker)

```jsonc
// all containers on the target servers
POST /read  { "type": "ListAllContainers", "params": {
    "servers": ["prod-01"], "terms": ["web"], "state": ["running"],
    "limit": 0, "sort_by": "Name" } }

// containers on one server
POST /read  { "type": "ListContainers", "params": { "server": "prod-01" } }

// one container
POST /read  { "type": "InspectContainer", "params": { "server": "prod-01", "container": "web" } }

// summary counts
POST /read  { "type": "GetContainersSummary", "params": {} }
```

Related: `ListNetworks`, `InspectNetwork`, `ListImages`, `InspectImage`, `ListImageHistory`, `ListVolumes`, `InspectVolume`, `ListComposeProjects`, `GetResourceMatchingContainer`.

## Logs

```jsonc
POST /read  { "type": "GetContainerLog", "params": {
    "server": "prod-01", "container": "web", "tail": 200, "timestamps": false } }

POST /read  { "type": "SearchContainerLog", "params": {
    "server": "prod-01", "container": "web", "terms": ["ERROR"],
    "combinator": "And", "invert": false } }
```

Stack/deployment equivalents: `GetStackLog`/`SearchStackLog`, `GetDeploymentLog`/`SearchDeploymentLog`, `GetSwarmServiceLog`/`SearchSwarmServiceLog`. Responses are `Log { stage, command, stdout, stderr, success, start_ts, end_ts }`. `tail` defaults ~50 and caps at 5000.

## State, stats, action-in-progress

```jsonc
POST /read  { "type": "GetServerState",       "params": {"server": "prod-01"} }
POST /read  { "type": "GetSystemInformation", "params": {"server": "prod-01"} }
POST /read  { "type": "GetSystemStats",       "params": {"server": "prod-01"} }
POST /read  { "type": "GetHistoricalServerStats", "params": {"server": "prod-01"} }
POST /read  { "type": "ListSystemProcesses",  "params": {"server": "prod-01"} }
POST /read  { "type": "GetStackActionState",  "params": {"stack": "my-stack"} }
```

`Get*ActionState` returns booleans (`pulling`, `deploying`, `stopping`, ...) — use it to avoid launching a second operation while one is running.

## Schedules and updates

```jsonc
POST /read  { "type": "ListSchedules", "params": {} }
POST /read  { "type": "GetUpdate",    "params": {"id": "<update-id>"} }
POST /read  { "type": "ListUpdates",  "params": {"page": 0} }
```

`ListUpdates` returns `{updates, next_page}`; pass `next_page` back as `page` for older runs.

## Summaries (dashboard-style counts)

`GetServersSummary`, `GetStacksSummary`, `GetDeploymentsSummary`, `GetBuildsSummary`, `GetReposSummary`, `GetProceduresSummary`, `GetActionsSummary`, `GetResourceSyncsSummary`, `GetAlertersSummary`, `GetBuildersSummary`, `GetSwarmsSummary`, `GetContainersSummary`. Each returns `{total, running, stopped, down, unhealthy, unknown}`.

## Export to TOML

```jsonc
POST /read  { "type": "ExportAllResourcesToToml", "params": {} }
POST /read  { "type": "ExportResourcesToToml",    "params": {"resources": [{"type":"Server","id":"prod-01"}]} }
```

See `patterns/resource-sync-toml.md`.

## Workflow example

```bash
# Find unhealthy prod stacks, then inspect the container behind one
curl -sS $CORE/read -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"ListStacks","params":{"query":{"terms":["prod"],"specific":{"states":["Unhealthy"]}},"limit":0}}'
curl -sS $CORE/read -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"GetStackLog","params":{"stack":"my-stack","services":[],"tail":100}}'
```

## Key rules

- Use `limit: 0` to fetch everything; otherwise page through with increasing `page`.
- `List*` items carry `id`, `name`, `tags`, and an `info` state block; fetch `Get*`/`ListFull*` for config.
- Prefer `Get*ActionState` over guessing whether an operation is still in flight.
