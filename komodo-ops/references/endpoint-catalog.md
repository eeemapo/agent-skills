# Endpoint Catalog

All requests are `POST` with body `{"type": "<Name>", "params": { ... }}` to the module path. Names below are the `type` values. `**Admin only**` / `**Super Admin**` are enforced server-side.

## `/read`

**Core / config**
`GetVersion`, `GetCoreInfo`, `ListSecrets`, `ListGitProvidersFromConfig`, `ListImageRegistriesFromConfig`

**Swarm**
`GetSwarmsSummary`, `GetSwarm`, `GetSwarmActionState`, `ListSwarms`, `ListFullSwarms`, `InspectSwarm`, `ListSwarmNodes`, `InspectSwarmNode`, `ListSwarmConfigs`, `InspectSwarmConfig`, `ListSwarmSecrets`, `InspectSwarmSecret`, `ListSwarmStacks`, `InspectSwarmStack`, `ListSwarmTasks`, `InspectSwarmTask`, `ListSwarmServices`, `InspectSwarmService`, `GetSwarmServiceLog`, `SearchSwarmServiceLog`, `ListSwarmNetworks`

**Server**
`GetServersSummary`, `GetServer`, `GetServerState`, `GetPeripheryInformation`, `GetServerActionState`, `ListServers`, `ListFullServers`

**Server stats / processes**
`GetSystemInformation`, `GetSystemStats`, `GetHistoricalServerStats`, `ListSystemProcesses`

**Terminal**
`ListTerminals`

**Containers / Docker**
`GetContainersSummary`, `ListAllContainers`, `ListContainers`, `InspectContainer`, `GetResourceMatchingContainer`, `GetContainerLog`, `SearchContainerLog`, `ListComposeProjects`, `ListNetworks`, `InspectNetwork`, `ListImages`, `InspectImage`, `ListImageHistory`, `ListVolumes`, `InspectVolume`

**Stack**
`GetStacksSummary`, `GetStack`, `GetStackActionState`, `GetStackLog`, `SearchStackLog`, `InspectStackContainer`, `InspectStackSwarmService`, `ListStacks`, `ListFullStacks`, `ListStackServices`, `ListAllStackServices`, `ListCommonStackExtraArgs`, `ListCommonStackBuildExtraArgs`

**Deployment**
`GetDeploymentsSummary`, `GetDeployment`, `GetDeploymentContainer`, `GetDeploymentActionState`, `GetDeploymentStats`, `GetDeploymentLog`, `SearchDeploymentLog`, `InspectDeploymentContainer`, `InspectDeploymentSwarmService`, `ListDeployments`, `ListFullDeployments`, `ListCommonDeploymentExtraArgs`

**Build**
`GetBuildsSummary`, `GetBuild`, `GetBuildActionState`, `GetBuildMonthlyStats`, `ListBuildVersions`, `ListBuilds`, `ListFullBuilds`, `ListCommonBuildExtraArgs`

**Repo**
`GetReposSummary`, `GetRepo`, `GetRepoActionState`, `ListRepos`, `ListFullRepos`

**Procedure / Action / Schedule**
`GetProceduresSummary`, `GetProcedure`, `GetProcedureActionState`, `ListProcedures`, `ListFullProcedures`, `GetActionsSummary`, `GetAction`, `GetActionActionState`, `ListActions`, `ListFullActions`, `ListSchedules`

**ResourceSync**
`GetResourceSyncsSummary`, `GetResourceSync`, `GetResourceSyncActionState`, `ListResourceSyncs`, `ListFullResourceSyncs`

**Builder / Alerter / Alert**
`GetBuildersSummary`, `GetBuilder`, `ListBuilders`, `ListFullBuilders`, `GetAlertersSummary`, `GetAlerter`, `ListAlerters`, `ListFullAlerters`, `ListAlerts`, `GetAlert`

**TOML export**
`ExportAllResourcesToToml`, `ExportResourcesToToml`

**Tag / Variable**
`GetTag`, `ListTags`, `GetVariable`, `ListVariables`

**Users / groups / permissions / keys**
`GetUsername`, `GetPermission`, `FindUser`, `ListUsers`, `ListApiKeys`, `ListApiKeysForServiceUser`, `ListPermissions`, `ListUserTargetPermissions`, `GetUserGroup`, `ListUserGroups`, `ListOnboardingKeys`

**Updates**
`GetUpdate`, `ListUpdates`

**Providers**
`GetGitProviderAccount`, `ListGitProviderAccounts`, `GetImageRegistryAccount`, `ListImageRegistryAccounts`

## `/write`

**Shared**
`UpdateResourceMeta`

**Swarm**
`CreateSwarm`, `CopySwarm`, `DeleteSwarm`, `UpdateSwarm`, `RenameSwarm`

**Server**
`CreateServer`, `CopyServer`, `DeleteServer`, `UpdateServer`, `RenameServer`, `CreateNetwork`, `UpdateServerPublicKey`, `RotateServerKeys`

**Terminal**
`CreateTerminal`, `DeleteTerminal`, `DeleteAllTerminals`, `BatchDeleteAllTerminals`

**Stack**
`CreateStack`, `CopyStack`, `DeleteStack`, `UpdateStack`, `RenameStack`, `WriteStackFileContents`, `RefreshStackCache`, `CheckStackForUpdate`, `BatchCheckStackForUpdate`

**Deployment**
`CreateDeployment`, `CopyDeployment`, `CreateDeploymentFromContainer`, `DeleteDeployment`, `UpdateDeployment`, `RenameDeployment`, `CheckDeploymentForUpdate`, `BatchCheckDeploymentForUpdate`

**Build**
`CreateBuild`, `CopyBuild`, `DeleteBuild`, `UpdateBuild`, `RenameBuild`, `WriteBuildFileContents`, `RefreshBuildCache`

**Repo**
`CreateRepo`, `CopyRepo`, `DeleteRepo`, `UpdateRepo`, `RenameRepo`, `RefreshRepoCache`

**Procedure / Action**
`CreateProcedure`, `CopyProcedure`, `DeleteProcedure`, `UpdateProcedure`, `RenameProcedure`, `CreateAction`, `CopyAction`, `DeleteAction`, `UpdateAction`, `RenameAction`

**ResourceSync**
`CreateResourceSync`, `CopyResourceSync`, `DeleteResourceSync`, `UpdateResourceSync`, `RenameResourceSync`, `WriteSyncFileContents`, `CommitSync`, `RefreshResourceSyncPending`

**Builder / Alerter**
`CreateBuilder`, `CopyBuilder`, `DeleteBuilder`, `UpdateBuilder`, `RenameBuilder`, `CreateAlerter`, `CopyAlerter`, `DeleteAlerter`, `UpdateAlerter`, `RenameAlerter`

**Onboarding keys** (admin)
`CreateOnboardingKey`, `UpdateOnboardingKey`, `DeleteOnboardingKey`

**Users / service users** (admin)
`PushRecentlyViewed`, `SetLastSeenUpdate`, `CreateLocalUser`, `DeleteUser`, `CreateServiceUser`, `UpdateServiceUserDescription`, `CreateApiKeyForServiceUser`, `DeleteApiKeyForServiceUser`, `CloseAlert`

**User groups** (admin)
`CreateUserGroup`, `RenameUserGroup`, `DeleteUserGroup`, `AddUserToUserGroup`, `RemoveUserFromUserGroup`, `SetUsersInUserGroup`, `SetEveryoneUserGroup`

**Permissions** (admin / super admin)
`UpdateUserAdmin`, `UpdateUserBasePermissions`, `UpdatePermissionOnResourceType`, `UpdatePermissionOnTarget`

**Tags**
`CreateTag`, `DeleteTag`, `RenameTag`, `UpdateTagColor`

**Variables** (admin)
`CreateVariable`, `UpdateVariableValue`, `UpdateVariableDescription`, `UpdateVariableIsSecret`, `DeleteVariable`

**Git / image-registry providers** (admin)
`CreateGitProviderAccount`, `UpdateGitProviderAccount`, `DeleteGitProviderAccount`, `CreateImageRegistryAccount`, `UpdateImageRegistryAccount`, `DeleteImageRegistryAccount`

## `/execute`

**Stacks**: `DeployStack`, `DeployStackIfChanged`, `PullStack`, `StartStack`, `RestartStack`, `PauseStack`, `UnpauseStack`, `StopStack`, `DestroyStack`, `RunStackService`

**Deployments**: `Deploy`, `PullDeployment`, `StartDeployment`, `RestartDeployment`, `PauseDeployment`, `UnpauseDeployment`, `StopDeployment`, `DestroyDeployment`

**Builds / repos**: `RunBuild`, `CancelBuild`, `CloneRepo`, `PullRepo`, `BuildRepo`, `CancelRepoBuild`

**Procedures / actions / syncs**: `RunProcedure`, `CancelProcedure`, `RunAction`, `CancelAction`, `RunSync`

**Containers (server-wide)**: `StartContainer`, `RestartContainer`, `PauseContainer`, `UnpauseContainer`, `StopContainer`, `DestroyContainer`, `StartAllContainers`, `RestartAllContainers`, `PauseAllContainers`, `UnpauseAllContainers`, `StopAllContainers`

**Docker maintenance**: `PruneContainers`, `PruneImages`, `PruneNetworks`, `PruneVolumes`, `PruneSystem`, `PruneDockerBuilders`, `PruneBuildx`, `DeleteNetwork`, `DeleteImage`, `DeleteVolume`

**Swarm**: `RemoveSwarmNodes`, `UpdateSwarmNode`, `RemoveSwarmStacks`, `RemoveSwarmServices`, `CreateSwarmConfig`, `RotateSwarmConfig`, `RemoveSwarmConfigs`, `CreateSwarmSecret`, `RotateSwarmSecret`, `RemoveSwarmSecrets`

**Alerters**: `TestAlerter`, `SendAlert`

**Maintenance (admin)**: `BackupCoreDatabase`, `ClearRepoCache`, `GlobalAutoUpdate`, `RotateAllServerKeys`, `RotateCoreKeys`

**Utility**: `None`, `Sleep`

**Batch** (all take `{pattern, tags?}`): `BatchRunAction`, `BatchRunProcedure`, `BatchRunBuild`, `BatchDeploy`, `BatchDestroyDeployment`, `BatchCloneRepo`, `BatchPullRepo`, `BatchBuildRepo`, `BatchDeployStack`, `BatchDeployStackIfChanged`, `BatchPullStack`, `BatchDestroyStack`

> `CommitSync` is the one execution-shaped request dispatched to `/write`.

## `/terminal/execute`

`POST /terminal/execute` with `ExecuteTerminalBody` `{target, terminal?, command, init?}` → streamed byte body (PTY output).

## `/auth`

Login / signup / self-service key management, JSON `{type, params}`. Confirmed members include `CreateApiKey` (self) and `SignUpLocalUser`. Login, OIDC, password reset, and 2FA request types live in this module — enumerate them from `GET <core-host>/docs`.

## Non-POST routes

| Route | Purpose |
|-------|---------|
| `GET /version` | Core version |
| `GET /docs` | Scalar OpenAPI UI (spec inlined) |
| `GET /user` | Authenticated user |
| `GET /client/{lib,types,responses,terminal}.{js,d.ts}` | Generated TS client/types |
| `GET /ws` | Websocket (updates / terminal I/O) |
| `/listener/{github,gitlab}/...` | Inbound git webhooks |
