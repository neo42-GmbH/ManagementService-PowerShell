# Neo42.MmsApi

PowerShell module for the REST API of the **neo42 Management Service (MMS)**.
It is the one way this repository talks to an MMS: it handles the connection,
the authentication, the error messages and `-WhatIf`, so a script only has to
express what it wants.

```powershell
Import-Module .\Neo42.MmsApi\Neo42.MmsApi.psd1

Connect-MmsApi -ServerName 'https://server.domain:4242'

Get-MmsClient | Format-Table Name, Domain, IsOnline, LastAccess
Get-MmsBitLockerReport | Format-Table ClientId, ComplianceState, EncryptionPercentage
```

It is a single module for the whole API, core and plug-ins together. The
plug-in separation lives in the command noun, so you can list just the part you
are licensed for:

```powershell
Get-Command -Module Neo42.MmsApi -Noun MmsApc*        # Application Package Center
Get-Command -Module Neo42.MmsApi -Noun MmsBitLocker*  # BitLocker plug-in
Get-Command -Module Neo42.MmsApi                      # everything
```

Every function has comment based help with examples: `Get-Help Get-MmsClient -Full`.

## Requirements

- Windows PowerShell 5.1
- The API listens on a **port of its own** (4242 by default). That is *not* the
  address of the Blazor UI.
- Authentication: Windows integrated (default) or a different Windows account
  via `-Credential`. See [Authentication](#authentication).

## Installing

The module works straight from the repository — every example script prefers an
installed copy and falls back to the one next to it, so a fresh clone needs no
installation:

```powershell
Import-Module .\Neo42.MmsApi\Neo42.MmsApi.psd1
```

To have it available in every session:

```powershell
.\Neo42.MmsApi\Tools\Install-MmsApiModule.ps1 -WhatIf   # shows where it would go
.\Neo42.MmsApi\Tools\Install-MmsApiModule.ps1
```

That installs module, help and the API snapshot into
`Documents\WindowsPowerShell\Modules\Neo42.MmsApi\<version>\`. Use
`-Scope AllUsers` for the machine wide path, which needs an elevated session.
Remove it again by deleting that folder. Check it in a **new** session:

```powershell
Get-Module -ListAvailable Neo42.MmsApi
Import-Module Neo42.MmsApi
```

## Quick start

```powershell
Import-Module Neo42.MmsApi

# Once per session: connect (checks /api/Version and the authentication)
Connect-MmsApi -ServerName 'https://server.domain:4242'

# Judge reachability, authentication and API documentation separately
Test-MmsApiConnection

# Work
Get-MmsClient | Format-Table Name, Domain, IsOnline, LastAccess
Get-MmsBitLockerReport | Format-Table ClientId, ComplianceState, EncryptionPercentage
Find-MmsApiRoute -Pattern 'wsus'
```

Optionally store a profile once, then the name is enough:

```powershell
Set-MmsConnectionProfile -Name 'Lab' -ServerName 'https://server.domain:4242' -SetAsDefault
Connect-MmsApi -ConnectionProfile 'Lab'
```

## Session

`Connect-MmsApi` creates a session object and makes it the default for every
following call. With `-PassThru` it is returned as well, so a script can address
several servers:

```powershell
$lab  = Connect-MmsApi -ServerName 'https://lab.domain:4242'  -PassThru
$prod = Connect-MmsApi -ServerName 'https://prod.domain:4242' -PassThru

Get-MmsClient -Session $lab
Get-MmsClient -Session $prod
```

| Function | Purpose |
| --- | --- |
| `Connect-MmsApi` | Open a session, check the address and the sign-in |
| `Get-MmsApiSession` | Which session is active (server, AuthMode, user, version)? |
| `Disconnect-MmsApi` | Discard the session including credential and token |
| `Test-MmsApiConnection` | Reachability, authentication, API documentation — separately |

Every function takes `-Session`. Resolution order, first match wins:

| # | Source | Purpose |
| --- | --- | --- |
| 1 | `-Session` | Session object, several servers in one script |
| 2 | Session | `Connect-MmsApi` |
| 3 | `DefaultProfile` | Default from the configuration file |

An address is named in exactly three places: `Connect-MmsApi`,
`Set-MmsConnectionProfile`, and `Test-MmsApiConnection` — the last one because
`Connect-MmsApi` verifies the address before storing the session, so on a broken
server there would be none left to diagnose with.

No wrapper takes a per-call address: it would carry no sign-in, and so drop a
`Connect-MmsApi -Credential` and run as the logged on user instead.

## Authentication

```powershell
Connect-MmsApi -ServerName $server                                # logged on Windows user
Connect-MmsApi -ServerName $server -UseDefaultCredential          # the same, explicitly
Connect-MmsApi -ServerName $server -Credential (Get-Credential)   # a different Windows account
```

Credentials live in the session object **only**, never in the configuration
file.

There is no bearer token mode. The MMS server does not issue API tokens for
administrative access, and even when it does it will not cover the whole API:
routes carrying the server side `WinAuthorize` attribute (deleting a client,
for example) evaluate a Windows principal and never a bearer token. Both modes
above produce one.

## Connection information

Lives **separately from the module** in a JSON file:

```
%USERPROFILE%\.neo42\mms.json
```

```json
{
  "DefaultProfile": "Lab",
  "Profiles": {
    "Lab": { "ServerName": "https://server.domain:4242", "Description": "Lab" }
  }
}
```

Addresses only, no secrets. An alternative path goes through `NEO42_MMS_CONFIG`.
Addresses without a scheme are completed to `https://` (`server.domain:4242`),
so scripts holding plain host names keep working. An explicitly different
scheme (`ftp://`, `file://`) is rejected.

## Functions

### Core

| Function | Purpose |
| --- | --- |
| `Invoke-MmsApiRequest` | The core: every call goes through here, and it is the supported fallback for a route without a wrapper |
| `Find-MmsApiRoute` | Search the documented API surface (offline) |
| `Get-/Set-/Remove-MmsConnectionProfile` | Manage profiles |
| `Get-MmsServerVersion` | `GET /api/Version` as a `[version]` |
| `Get-MmsServerTime` | `GET /api/TimeService/1`, the cheapest reachability probe |

### Clients and filters

| Function | Route | Kind |
| --- | --- | --- |
| `Get-MmsClient` | `/api/Client[/{id}\|/{domain}/{name}]` | read |
| `Remove-MmsClient` | `/api/ServiceInfrastructureV3/{id}` | **deletes the client and all of its plug-in reports** |
| `Get-MmsFilter` | `/api/criteriastorev3[/{id}]` | read (`-ExpandCriteria`, `-Name`) |
| `Get-MmsFilterEvaluation` | `/api/CriteriaGroupEvalDuration` | read (`-Latest`) |
| `New-MmsFilter` | `/api/criteriastorev3[/cancreate/{type}\|/create/{type}]` | **write** |
| `Set-MmsFilter` | `/api/criteriastorev3` | **write** |

`Get-MmsClient -Name` expects the short name (`CLIENT2`). The `NetBiosName`
field of the result holds `DOMAIN\NAME` and is not what the route matches on.

### Client management plug-ins

| Function | Route | Kind |
| --- | --- | --- |
| `Get-MmsBitLockerReport` | `/api/BitlockerReportV4[/{id}]` | read |
| `Get-MmsBitLockerPolicy` | `/api/BitlockerPolicy[/{id}]` | read |
| `Get-MmsBitLockerRecoveryKey` | `/api/Bitlocker{Ad\|Inbuilt}RecoveryKey?clientId=` | read, **secrets** |
| `Get-MmsBitLockerRecoveryKeyBackup` | `/api/BitlockerRecoveryKeyBackup[/{clientId}]` | read, **secrets** |
| `Get-MmsDeviceInformation` | `/api/DeviceInformationV2[?type=\|/{id}]` | read |
| `Get-MmsDriveMonitoringReport` | `/api/DriveMonitoringReport[/{id}]` | read |
| `Get-MmsMaintenanceRebootReport` | `/api/MaintenanceReportV3[/{id}]` | read |
| `Get-MmsEmpirumMonitoringReport` | `/api/EmpirumMonitoringReportV2[/{id}]` | read |
| `Get-MmsServiceInfrastructureReport` | `/api/ServiceInfrastructureV3[/{id}]` | read |
| `Get-MmsWsusComputerTarget` | `/api/WsusComputerTargetV2[/{id}]` | read |
| `Get-MmsWsusUpdateSummary` | `/api/WsusUpdateSummariesPerComputerV2[/{id}]` | read |

`Get-MmsDeviceInformation -Type` splits the inventory into areas: `sw` fills
`Software`, `cert` and `os` fill `OperatingSystem`, `hw` fills `Hardware`, and
the remaining sub objects stay null.

### Notification Center and Notification Service

| Function | Route | Kind |
| --- | --- | --- |
| `Get-MmsNotificationCenterTarget` | `/api/NotificationCenter/Target/All` | read |
| `Get-MmsNotification` | `/api/NotificationCenter/Notifications[/All\|/{id}]` | read |
| `Send-MmsClientNotification` | `/api/NotificationCenter/Notifications` | **write** |
| `Remove-MmsNotification` | `/api/NotificationCenter/Notifications/{id}` | **delete** |
| `Remove-MmsPendingNotification` | `/api/NotificationCenter/NotificationTarget/Pending` | **delete, global** |
| `Send-MmsClientMessage` | `/api/StoreableNotification` | **write** |

### Application Package Center — Empirum cleanup

| Function | Route | Kind |
| --- | --- | --- |
| `Get-MmsApcEmpCleanupTenant` | `/api/apc/tenant[/all\|/{id}]` | read |
| `Get-MmsApcEmpCleanupPackageList` | `/api/apc/EmpirumCleanup/CleanupItems` | read |
| `Get-MmsApcEmpCleanupJob` | `/api/apc/EmpirumCleanupJob[/{id}\|/all]` | read |
| `Get-MmsApcEmpCleanupProtocol` | `/api/apc/EmpirumCleanup/Protocols` | read |
| `Get-MmsApcEmpCleanupDirectorySize` | `/api/apc/EmpirumCleanup/CalculateSize` | read |
| `Test-MmsApcEmpCleanupDuplicates` | `/api/apc/EmpirumCleanup/CheckForDuplicates` | POST, checks only |
| `New-MmsApcEmpCleanupJob` | `/api/apc/EmpirumCleanupJob` | **write** |
| `Start-MmsApcEmpCleanupJob` | `/api/apc/EmpirumCleanup/StartEmpirumCleanupJob` | **deletes packages** |
| `Remove-MmsApcEmpCleanupJob` | `/api/apc/EmpirumCleanupJob/{id}` | **write** |

### Application Package Center — pipelines, network drives, packages

| Function | Route | Kind |
| --- | --- | --- |
| `Get-MmsApcPipeline` | `/api/apc/Pipelines[/{id}]` | read |
| `Find-MmsApcPipeline` | `/api/apc/PipelineSpecificationItem/Filtered` | POST, searches only |
| `Get-MmsApcPipelineRun` | `/api/apc/PipelineRun[/{id}\|/GetMany/{pipelineId}]` | read (+ `StateName`) |
| `Get-MmsApcPipelineProtocol` | `/api/apc/PipelineProtocol/GetMany/...` | read |
| `Wait-MmsApcPipelineRun` | polls `PipelineRun/{id}` | read |
| `Get-MmsApcPipelineVariable` | `/api/apc/PipelineVariable[/all\|/{id}]` | read |
| `Get-MmsApcNetworkDrive` | `/api/apc/NetworkDrive[/all\|/{id}\|?tenantId=\|/exists]` | read |
| `Get-MmsApcNetworkDriveFile` | `/api/apc/NetworkDrive/Files` | POST, reads only |
| `Get-MmsApcPackageInfo` | `/api/apc/PackageInfo/all/...` | read |
| `Get-MmsApcDefaultPackage` | `/api/apc/DefaultPackage/all/{kind}` | read |
| `Get-MmsApcPackageSyncJob` | `/api/apc/PackageInteraction/LatestSyncJob` | read |
| `Start-MmsApcPipeline` | `/api/apc/PipelineInteraction/run` | **starts real work** |
| `Stop-MmsApcPipelineRun` | `/api/apc/PipelineInteraction/cancel` | **write** |
| `Remove-MmsApcPipelineRun` | `/api/apc/PipelineRun/{id}` | **delete** |
| `Remove-MmsApcPipelineVariable` | `/api/apc/PipelineVariable/{id}` | **delete** |
| `Start-MmsApcPackageSync` | `/api/apc/PackageInteraction/StartSync` | **write** |

The published API cannot create or change pipelines and pipeline variables —
that happens in the APC UI, and the API triggers and monitors. There is no
wrapper for it here: creating a pipeline is outside the published surface, and
this module wraps the published surface only.

`Start-MmsApcPipeline` requires the Windows user to be in the local
`Neo42MgmtSvcAdmins` group on the MMS server, and the trigger route additionally
checks the `TRIGGER_PIPELINE` policy.

## Write access and `-WhatIf`

Every call that is not a `GET` goes through `ShouldProcess`, so show it first:

```powershell
Remove-MmsClient -ClientId $client.Id -WhatIf
Set-MmsFilter -Filter $filter -Criteria $criteria -WhatIf
```

`-WhatIf` and `-Confirm` also work **across the module boundary**, which
PowerShell does not do by itself: a module function runs in module scope and
does not inherit `$WhatIfPreference` or `$ConfirmPreference` from a calling
script. This module reads the caller's preferences explicitly, so both
directions behave as expected in your own scripts:

```powershell
# only shows, changes nothing
.\API\Housekeeping\Client-Housekeeping-LastContact_based.ps1 -ServerName $server -RemoveAfterDays 90 -WhatIf

# asks per client, even though the script sets -Confirm:$false internally
.\API\Housekeeping\Client-Housekeeping-LastContact_based.ps1 -ServerName $server -RemoveAfterDays 90 -Confirm

# without a switch: runs unattended, no prompt
.\API\Housekeeping\Client-Housekeeping-LastContact_based.ps1 -ServerName $server -RemoveAfterDays 90
```

Always show `-WhatIf` first before the first real change on a system.

## Response shapes and `-Unwrap`

The API uses several envelopes. `Invoke-MmsApiRequest` therefore returns the
**raw** deserialized response by default; unwrapping is opt-in:

| Shape | Example | Handling |
| --- | --- | --- |
| bare array | `GET /api/Client` | use directly |
| `{ Success, Item, Error }` (`ResultModel`, `GetItemResponse`) | `GET /api/apc/tenant/all` | `-Unwrap` returns `Item`, throws on `Success = false` |
| `{ Data, Errors, Meta }` | `GET /api/ServiceInfrastructureV3` | `-Unwrap` returns `Data`, throws when `Errors` is filled |

Recognizable in the catalog: if `Returns` holds a `ResultModel[...]` or
`GetItemResponse[...]`, `-Unwrap` makes sense. **Not** every route of a
controller uses the same envelope — `/api/ServiceInfrastructureV3` wraps,
`/api/ServiceInfrastructureV3/{id}` does not. When in doubt, check against a
server.

Three "nothing found" answers to expect, because none of them is an error:

- Some routes answer with the literal **text** `null`
  (`/api/BitlockerInbuiltRecoveryKey/{id}`). `Invoke-MmsApiRequest` turns that
  into "no output", so `$null -eq` checks work.
- `/api/WsusComputerTargetV2/{id}` answers an unknown name with a completely
  empty object whose `Id` is the empty GUID.
- `/api/DeviceInformationV2` accepts an **unknown** `type` and answers with the
  usual record and everything null — which looks exactly like a client that has
  not inventoried yet.

## The published API surface is the scope

Only what appears in the server's swagger documentation is released by neo42 for
automation. The server also has routes it does not publish; those can change or
disappear with any MMS release without notice, so **this module does not wrap
them** — every function here calls a published route, and
`Tests\Unit\ApiSurface.Tests.ps1` fails the suite if one does not.

A capability the published surface does not offer is therefore missing from this
module on purpose, rather than covered by a wrapper that might break silently.

- Look up the surface: [`docs/api-catalog.md`](docs/api-catalog.md) or `Find-MmsApiRoute`
- `Invoke-MmsApiRequest` **warns** (once per route and session) when a route is
  not in the catalog — treat it as a finding, not as noise. `-SkipRouteCheck`
  exists for the two cases where the check cannot apply: fetching the swagger
  document itself (`Tools\Update-MmsApiCatalog.ps1`) and a snapshot that is
  older than the server.
- The swagger documentation is only served when the server setting
  `EnableApiDocumentation` is active (`Test-MmsApiConnection` reports it).

Refresh the catalog after an MMS update, or when a route is missing:

```powershell
.\Tools\Update-MmsApiCatalog.ps1
```

That writes `docs/swagger-v1.json` (the raw document),
`docs/swagger-v1.meta.json` (server version and date) and
`docs/api-catalog.md`. `Connect-MmsApi` warns when the server version no longer
matches the version of the catalog.

`docs\` is not documentation for humans only, which is why it ships with the
module: `Find-MmsApiRoute` reads the snapshot, and `Invoke-MmsApiRequest` uses
it for the undocumented-route warning.

## Tests

```powershell
.\Tests\Invoke-MmsTests.ps1                      # offline, needs no server
.\Tests\Invoke-MmsTests.ps1 -Scope Integration   # read-only against the configured server
.\Tests\Invoke-MmsTests.ps1 -Scope Write         # writing, in a lab only
```

Needs Pester 6, and for Integration/Write a hand-written
`Tests\mms.tests.config.psd1` (the template sits next to it). Details and the
rules for writing a test: [`Tests/README.md`](Tests/README.md).

## Related

- Example scripts that use this module: [`..\API`](../API)
- Changing the module — layout, naming, adding an endpoint, releasing:
  [`CONTRIBUTING.md`](CONTRIBUTING.md)
- neo42 Management Service product documentation for the meaning of the plug-ins
  and subscriptions
