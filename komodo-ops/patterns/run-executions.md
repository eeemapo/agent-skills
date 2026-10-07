# Run Executions

Use when: you need to deploy, build, sync, start/stop/restart/pause, or run Docker maintenance on Komodo resources. All mutating actions are **executions** posted to `/execute`.

## Shape

```http
POST /execute
{ "type": "DeployStack", "params": { "stack": "my-stack" } }
```

Returns an `Update`. Poll `/read/GetUpdate` with its `id` until `status == "Complete"`, then check `success` and read `logs[].stdout`/`stderr`.

```jsonc
{"type":"GetUpdate","params":{"id":"<update-id>"}}
```

Use `Get*ActionState` (`/read`) while waiting to see live per-resource booleans. The bundled `scripts/komodo_api.py ... execute <Type> --wait` does the `GetUpdate` polling for you and exits non-zero on failure.

## Convention: recreate, don't just stop/restart

**To apply a change, destroy and re-deploy — not stop/deploy.** Default:

```
DestroyStack  ->  DeployStack
```

`RestartStack` / `StopStack` + `StartStack` cycle the **existing** containers;
they do not recreate them, so a changed bind-mounted file (e.g. `./config.yaml`)
is never re-read and a config edit can silently take no effect. `DestroyStack`
(containers removed; named volumes persist) followed by `DeployStack` guarantees
a clean recreate that picks up the new file.

- Use **destroy/deploy** whenever applying an edit to a stack's files or env.
- `DeployStackIfChanged` is the lighter option when a full recreate isn't wanted.
- Plain stop/start/restart is only for cycling processes when the container
  definition is unchanged.
- Caveat: `DestroyStack` releases containers (and any ephemeral state) while
  named volumes persist — confirm the stack's data is volume-backed first.

## Execution catalog (by area)

### Stacks (`docker compose`)
`DeployStack`, `DeployStackIfChanged`, `PullStack`, `StartStack`, `RestartStack`, `PauseStack`, `UnpauseStack`, `StopStack`, `DestroyStack`, `RunStackService`.
Params commonly `{stack, services?: [], stop_time?}`; `DestroyStack` also `{remove_orphans}`; `RunStackService` `{stack, service, command?, env?, detach?, ...}`.

### Deployments (single containers)
`Deploy`, `PullDeployment`, `StartDeployment`, `RestartDeployment`, `PauseDeployment`, `UnpauseDeployment`, `StopDeployment`, `DestroyDeployment`.

### Builds / repos
`RunBuild`, `CancelBuild`, `CloneRepo`, `PullRepo`, `BuildRepo`, `CancelRepoBuild`.

### Procedures / actions / syncs
`RunProcedure`, `CancelProcedure`, `RunAction`, `CancelAction`, `RunSync`.
`RunAction` accepts `{action, args?}` to merge custom variables over defaults (also used by webhooks).

### Server-wide container management
`StartContainer`/`RestartContainer`/`PauseContainer`/`UnpauseContainer`/`StopContainer`/`DestroyContainer`,
`StartAllContainers`/`RestartAllContainers`/`PauseAllContainers`/`UnpauseAllContainers`/`StopAllContainers`.

### Docker maintenance (destructive)
`PruneContainers`, `PruneImages`, `PruneNetworks`, `PruneVolumes`, `PruneSystem`, `PruneDockerBuilders`, `PruneBuildx`, `DeleteNetwork`, `DeleteImage`, `DeleteVolume`.
`PruneSystem` removes volumes — highest blast radius.

### Swarm
`RemoveSwarmNodes`, `UpdateSwarmNode`, `RemoveSwarmStacks`, `RemoveSwarmServices`, `CreateSwarmConfig`/`RotateSwarmConfig`/`RemoveSwarmConfigs`, `CreateSwarmSecret`/`RotateSwarmSecret`/`RemoveSwarmSecrets`.

### Alerters
`TestAlerter`, `SendAlert`.

### Core maintenance (admin only)
`BackupCoreDatabase`, `ClearRepoCache`, `GlobalAutoUpdate` (`{skip_auto_update?}`), `RotateAllServerKeys`, `RotateCoreKeys` (`{force?}`). See `references/core-operations.md`.

### Utility
`None` (no-op), `Sleep` (`{duration_ms}`).

> `CommitSync` is special: it is dispatched to `/write`, not `/execute` (see `patterns/resource-sync-toml.md`).

## Batch executions

Every common execution has a parallel `Batch*` variant taking a wildcard/regex `pattern` plus optional `tags`:

```jsonc
POST /execute { "type": "BatchDeployStack", "params": {
    "pattern": "prod-*", "tags": ["prod"] } }
```

`pattern` supports multiline and comma-delineated combinations of names, globs, and regexes. Batch executions return `{status, data}` items (or per-item errors) rather than a single `Update`; poll each returned update id.

Batch variants exist for: `RunAction`, `RunProcedure`, `RunBuild`, `Deploy`, `DestroyDeployment`, `CloneRepo`, `PullRepo`, `BuildRepo`, `DeployStack`, `DeployStackIfChanged`, `PullStack`, `DestroyStack`.

## Resolve targets first

Because batch patterns can be broad, **first** enumerate what would match, then execute:

```bash
curl -sS $CORE/read -H 'Content-Type: application/json' -H "X-Api-Key: $K" -H "X-Api-Secret: $S" \
  -d '{"type":"ListStacks","params":{"query":{"terms":["prod"]},"limit":0}}'
```

## Safety

- To apply a config/mount change, **recreate** (`DestroyStack` -> `DeployStack`); stop/restart won't reload a changed mounted file. See the convention above.
- Destructive: `Destroy*`, `Delete*`, `Prune*`, `Stop*`, `Remove*`. Confirm with the user; never blanket-batch a wildcard you have not enumerated.
- Execution results are asynchronous: a 200 only means *queued/started*. Always poll `GetUpdate`.
- `GlobalAutoUpdate` can redeploy many resources at once; scope it or pass `skip_auto_update`.

## Workflow example — safe restart

```bash
# 1) confirm state
curl .../read -d '{"type":"GetStackActionState","params":{"stack":"my-stack"}}'
# 2) run
curl .../execute -d '{"type":"RestartStack","params":{"stack":"my-stack"}}'
# 3) poll (repeat until Complete)
curl .../read -d '{"type":"GetUpdate","params":{"id":"<update-id>"}}'
```
