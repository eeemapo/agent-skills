# Run Executions

**Use when** you need to deploy, build, sync, start/stop/destroy, or run Docker maintenance
on Komodo resources. Everything mutating is an **execution**.

## Typed `_action` tools already poll

`komodo_stack_action`, `komodo_deployment_action`, `komodo_container_action`,
`komodo_server_action`, `komodo_build_action`, `komodo_repo_action`,
`komodo_procedure_action`, `komodo_action_action`, `komodo_resource_sync_action`,
`komodo_swarm_action` are long-running: they submit the execution and **poll the `Update` to
completion** (1 s interval, 30 min cap, reporting real per-stage progress), then return the
finished `Update`. You do **not** poll `GetUpdate` yourself.

On `komodo_raw` you do: an execute returns an `Update` whose `id` you poll with
`GetUpdate` until `status == "Complete"`, then check `success` and `logs`. Update lifecycle
is `Queued → InProgress → Complete`, with one log entry per completed stage.

## Convention: recreate, don't just stop/restart

**To apply a change, destroy and re-deploy — not stop/deploy.**

```
komodo_stack_action { action: "destroy", stack: "my-stack" }   # containers removed; named volumes persist
komodo_stack_action { action: "deploy",  stack: "my-stack" }   # clean recreate
```

`start`/`stop`/`restart` cycle the **existing** containers; a changed bind-mounted file is
never re-read, so an edit can silently take no effect while everything looks healthy.

- Use destroy → deploy whenever applying an edit to a stack's files or env.
- `pull`, then `deploy` when only the image moved.
- Plain start/stop/restart is only for cycling processes whose definition is unchanged.
- `destroy` releases containers and ephemeral state; **named volumes persist** — confirm the
  stack's data is volume-backed first.

### Never stop/start/restart a stack with a Tailscale sidecar

If the compose file uses `network_mode: service:ts`, restart or stop+start break the
companions: the sidecar returns but the others do **not** rejoin its network namespace, so
the stack is unreachable on the tailnet while every container still reports *healthy*.

This is why **`komodo_stack_action action="restart"` is refused** by the tool — it throws
with instructions rather than silently re-mapping. Recreate instead. A wildcard/tagged batch
is not a way around it either.

### Never restart the stack that carries your own route

`litellm` is the gateway this agent's own `litellm/*` model calls travel through. **A
restart is the dangerous verb**: it can leave the stack in a state a following redeploy does
not cleanly recover, and it severs inference mid-turn. A plain **redeploy** is fine — the
stack comes back. Plan the window with the user and confirm the gateway's own API answers
afterwards.

### Verify the change actually loaded

A recreate can race the repo sync: the container starts *before* the edited file lands, then
serves stale config while looking perfectly healthy. After recreating, prove the change took
effect **through the service's own interface** — never by checking that the file exists.

## Execution catalog

### Stacks (`komodo_stack_action`)
`deploy`, `pull`, `start`, `pause`, `unpause`, `stop`, `destroy` — **`restart` refused**.
Raw equivalents carry extra params: `DeployStackIfChanged`, `RunStackService`
(`{stack, service, command?, env?, detach?}`, `DestroyStack {remove_orphans}`).

### Deployments (`komodo_deployment_action`)
`deploy`, `pull`, `start`, `restart`, `pause`, `unpause`, `stop`, `destroy`.

### Containers (`komodo_container_action`)
`start`, `stop`, `restart`, `pause`, `unpause`.

### Servers (`komodo_server_action`)
Batch lifecycle: `start_all_containers`, `restart_all_containers`, `pause_all_containers`,
`unpause_all_containers`, `stop_all_containers`. Pruning: `prune_containers`,
`prune_images`, `prune_volumes`, `prune_networks`, `prune_system`, `prune_docker_builders`,
`prune_buildx`. Deletions (need `name`): `delete_network`, `delete_image`, `delete_volume`.
**These act on every container on the host** — a batch lifecycle action on a shared server
is a full outage; `prune_system` removes volumes.

### Builds / repos / builders
`komodo_build_action { build, action: "run" | "cancel" }`;
`komodo_repo_action { repo, action: "clone" | "pull" | "build" | "cancel_build" }`;
`komodo_build_logs { update_id }` for per-stage output after a run.

### Procedures / actions / syncs
`komodo_procedure_action { procedure, action: "run" }`;
`komodo_action_action { action_id, action: "run", args? }` (custom args merge over defaults,
as webhooks use); `komodo_resource_sync_action { resource_sync, action: "run" | "refresh" }`.
`CommitSync` is the exception: it is a **write**, not an execute — see
[`resource-sync-toml.md`](resource-sync-toml.md).

### Swarms (`komodo_swarm_action`)
`update_node` (availability/role/labels), `remove_nodes`, `remove_services`,
`remove_stacks`. Swarm config/secret ops are raw.

### Maintenance and admin (raw)
`PruneContainers`/`PruneImages`/`PruneNetworks`/`PruneVolumes`/`PruneSystem`/… group under
the typed `komodo_server_action` above. Raw-only: `TestAlerter`, `SendAlert`, and Core
maintenance — `BackupCoreDatabase`, `ClearRepoCache`, `GlobalAutoUpdate {skip_auto_update}`,
`RotateAllServerKeys`, `RotateCoreKeys {force}` (see
[`../references/core-operations.md`](../references/core-operations.md)). Admin-only.

## Batch executions (raw)

Every common execution has a `Batch*` variant taking a wildcard/regex `pattern` plus
optional `tags`:

```
komodo_raw { op: "BatchDeployStack", args: { pattern: "prod-*", tags: ["prod"] } }
```

`pattern` accepts multiline and comma-delineated combinations of names, globs, and regexes.
Batch calls return `{status, data}` items (or per-item errors) rather than one `Update`; each
returned update id must be polled separately. Batch variants exist for `RunAction`,
`RunProcedure`, `RunBuild`, `Deploy`, `DestroyDeployment`, `CloneRepo`, `PullRepo`,
`BuildRepo`, `DeployStack`, `DeployStackIfChanged`, `PullStack`, `DestroyStack`.

## Resolve targets first

Because patterns can be broad, **enumerate what would match, then execute** — never blanket a
wildcard you have not listed:

```
komodo_stack_list { page_size: 100 }        # who actually matches "prod-*"?
```

## Safety

- **The confirmation gate is off in this deployment** (`confirmDestructive: false`), so
  nothing prompts. Confirm with the user before anything destructive; see
  [`use-the-extension.md`](use-the-extension.md).
- Destructive verbs: `destroy`, `_delete`, `prune_*`, `stop`, `remove_*`. Highest blast
  radius: `prune_system` (volumes) and `destroy`.
- To apply a config or mount change, **recreate**; stop/restart will not reload it.
- Execution success is asynchronous: poll (typed tools do it for you) and then read
  `success` and `logs` — a returned `Update` is evidence, a started request is not.
- `GlobalAutoUpdate` can redeploy many resources at once; scope it or pass
  `skip_auto_update`.
