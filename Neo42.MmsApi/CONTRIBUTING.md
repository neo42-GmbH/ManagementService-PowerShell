# Contributing to Neo42.MmsApi

PowerShell 5.1 client for the REST API of the neo42 Management Service (MMS).

This module is part of the public example repository `ManagementService-PowerShell`.
Read `README.md` for what the module does and how it is used, `docs\api-catalog.md`
for the released API surface, and `Tests\README.md` before touching tests.

## The one rule: this module is how the examples talk to the MMS

Every interaction with an MMS — checking something, exporting something,
changing something — goes through this module. The example scripts under
`..\API\` contain no `Invoke-RestMethod` call against an MMS of their own. (The
one script with its own REST calls,
`..\API\Troubleshooting\WSO_Version_Issue_Package_Detection.ps1`, talks to a
Workspace ONE tenant and not to an MMS at all.)

- Function exists → use it.
- Function missing → **add it here** (see "Adding an endpoint"), then use it.
- Function wrong or incomplete → **fix it here**, then use it.
- Route needed that no wrapper covers yet and the task is a one-off → use
  `Invoke-MmsApiRequest -Path ...` (the supported fallback: it still gives
  session handling, auth, error handling, `-WhatIf` and the undocumented-route
  warning), and add the wrapper if it is going to be used again.

Please do not add ad-hoc `Invoke-RestMethod` / `Invoke-WebRequest` calls against
the MMS. Whatever we learn about the API belongs in this module, where every
caller gets it.

## Layout

One module, not one per plug-in: every function shares the session created by
`Connect-MmsApi`, and PowerShell keeps module session state per module. The
plug-in separation lives in the command noun instead, so
`Get-Command -Module Neo42.MmsApi -Noun MmsBitLocker*` gives that grouping for
free.

- `Neo42.MmsApi.psd1` — manifest; `FunctionsToExport` must list every file under
  `Public\` (the loader warns about drift on import)
- `Neo42.MmsApi.psm1` — dot-sources `Private\*.ps1` and `Public\**\*.ps1`
  (**recursively** — a new subfolder needs no loader change)
- `Public\<Area>\` — one exported function per file, area folders mirror the
  plug-ins: `Core`, `Information`, `Clients`, `Filter`, `Apc`, `BitLocker`,
  `DeviceInformation`, `DriveMonitoring`, `EmpirumAgentMonitoring`,
  `MaintenanceReboot`, `ServiceInfrastructure`, `Wsus`, `NotificationCenter`,
  `NotificationService`
- `Private\` — internal helpers (session, config, uri, auth, error handling,
  swagger, enums)
- `Tools\Update-MmsApiCatalog.ps1` — refreshes the swagger snapshot and the catalog
- `Tools\Build-MmsApiRelease.ps1` — stages a clean copy for release
- `Tools\Install-MmsApiModule.ps1` — installs that copy into a module directory
- `Tests\` — Pester 6 suite, three levels (`Unit` offline, `Integration` read
  only, `Write` lab only). Rules for writing one: `Tests\README.md`
- `docs\api-catalog.md` — documented routes grouped by plug-in (generated)
- `docs\swagger-v1.json` — swagger 2.0 snapshot; query it, never read it whole
- `docs\swagger-v1.meta.json` — server version and date of the snapshot

`docs\` is **not** documentation for humans only: `Find-MmsApiRoute` reads the
snapshot, and `Invoke-MmsApiRequest` uses it to warn about undocumented routes.
It ships with the module.

Connection profiles live outside the module in `%USERPROFILE%\.neo42\mms.json`
(addresses only, never credentials).

## Naming

- Session and transport use the `MmsApi` noun: `Connect-MmsApi`,
  `Disconnect-MmsApi`, `Get-MmsApiSession`, `Test-MmsApiConnection`,
  `Invoke-MmsApiRequest`, `Find-MmsApiRoute`.
- Stored addresses use `MmsConnectionProfile`, matching the
  `-ConnectionProfile` parameter.
- Everything else is `Verb-Mms<Plugin><Noun>`, singular:
  `Get-MmsBitLockerReport`, `Get-MmsApcPipelineRun`, `Get-MmsWsusComputerTarget`.
- A function is named after **what it does**, not after the controller it lives
  on. `Remove-MmsClient` calls `DELETE /api/ServiceInfrastructureV3/{id}`,
  because that is the supported client removal — `DELETE /api/Client/{id}` is
  marked `[Obsolete]` in the server.

## Rules

- Every call goes through `Invoke-MmsApiRequest`. Never `Invoke-RestMethod`
  directly in a wrapper.
- Every public function takes `-Session` and forwards it. Nothing else. Do not
  write a `.PARAMETER Session` block — it is the same sentence on every
  function, documented once here and in the README. Every *other* parameter
  needs one, and the hygiene tests check the description, not just the name.
  `Resolve-MmsApiSession` defines the precedence in exactly one place:
  `-Session`, then the connection from `Connect-MmsApi`, then `DefaultProfile`.
- **A wrapper never takes an address.** `-ServerName` and `-ConnectionProfile`
  belong on `Connect-MmsApi` and `Set-MmsConnectionProfile` only, plus
  `Test-MmsApiConnection`, which has to work when there is no session left to
  resolve. A per-call address carries no sign-in, so it would drop a
  `Connect-MmsApi -Credential` and run as the logged on user — on a
  `WinAuthorize` route that is the wrong principal, not a clean failure.
  `Module.Hygiene.Tests.ps1` fails the suite for a new one.
- Authentication comes from the session: Windows integrated (default) or
  `-Credential`, never written to disk. There is no bearer token mode — the
  server issues none, and `WinAuthorize` routes need a Windows principal
  regardless. Add the parameter when the server side exists.
- **Write paths use `Test-MmsShouldProcess`, never `$PSCmdlet.ShouldProcess`
  directly, and never the one inside `Invoke-MmsApiRequest` either.** A module
  function runs in module scope and does not inherit `$WhatIfPreference` or
  `$ConfirmPreference` from a calling script, and a nested call sees the module
  scope as its caller — either way the script's preference is lost, so a script
  started with `-WhatIf` would delete for real.
  `Test-MmsShouldProcess` reads both preferences through
  `$PSCmdlet.SessionState` at the caller.
- **Only routes published through swagger are in scope.** `docs\api-catalog.md`
  and `Find-MmsApiRoute` are the surface this module wraps, and the whole of it.
  The server also has routes it does not publish (`[ApiExplorerSettings(IgnoreApi
  = true)]`); those are not released for automation, so no wrapper may call one.
  `Invoke-MmsApiRequest` warns when a path is not in the snapshot, and
  `Tests\Unit\ApiSurface.Tests.ps1` fails the suite for it. There is no exception
  list and no label — not `EXPERIMENTAL`, not a note in the help — that makes a
  hidden route acceptable here.
- A capability the published surface does not cover is **out of scope for this
  module**. Do not work around it with a wrapper on a hidden route: leave the
  gap, and say so where the feature was asked for. A hidden write route is the
  sharpest version of this — it can change *what it does to data* rather than
  merely failing — but the rule is the same for reads.
- Return the raw response by default; `-Unwrap` handles the
  `{ Success, Item, Error }` and `{ Data, Errors, Meta }` envelopes. Check the
  catalog column `Returns`: `ResultModel[...]` / `GetItemResponse[...]` means
  `-Unwrap`. Not every route on a controller uses the same envelope —
  `/api/ServiceInfrastructureV3` wraps, `/api/ServiceInfrastructureV3/{id}` does
  not. Verify against a server, do not assume.
- Watch for routes that signal "nothing found" oddly: a response body of the
  literal string `null`, an all-null object whose `Id` is the empty guid
  (`/api/WsusComputerTargetV2/{id}`), or an accepted but unknown `type`
  (`/api/DeviceInformationV2`). `README.md` lists the known ones.
- Numeric API enums get readable parameter values (`ValidateSet` plus a lookup
  table in `Private\`), never `Add-Type` enums.
- `*.ps1` / `*.psm1` / `*.psd1` are **UTF-8 with BOM**, CRLF, tab indented, with
  comment based help including at least one example. The BOM matters: PowerShell
  5.1 reads UTF-8 without a BOM as ANSI and mangles umlauts.
- Nothing in this folder may name an internal host, domain or account — the
  repository is public. `Tools\Update-MmsApiCatalog.ps1` deliberately keeps the
  host and the user out of the generated snapshot metadata.
- No TLS validation workarounds.

## Adding an endpoint

1. `Find-MmsApiRoute -Pattern 'wsus'` — method, path, query, body, return type.
2. Details from the snapshot: `$doc.definitions.'<full type name>'.properties`.
3. New file `Public\<Area>\<Verb>-Mms<Noun>.ps1`, thin: validate, build path,
   call `Invoke-MmsApiRequest`, `-Unwrap` if the route uses an envelope.
4. Add the name to `FunctionsToExport` in the psd1.
5. Add the route to the list in `Tests\Unit\ApiSurface.Tests.ps1`, and any new
   field the wrapper reads to the contract table in `Tests\README.md`.
6. `Tests\Invoke-MmsTests.ps1` — offline, no server needed. It checks the
   manifest, the encoding, complete help, and that a write function uses
   `Test-MmsShouldProcess`. A new write function is also picked up by the
   data driven cases in `Tests\Unit\Test-MmsShouldProcess.Tests.ps1`.
7. Add the function and its route to the table in `README.md`.
8. Test read paths for real, write paths with `-WhatIf` first.

## Before a pull request

```powershell
.\Tests\Invoke-MmsTests.ps1
```

Offline, needs no server, and has to be green. Run it **once from a real
console** as well, not only from a script or a CI job: a prompt behaves
differently in a host that can ask a human — `Tests\README.md` rule 11.

## After an MMS update

```powershell
.\Tools\Update-MmsApiCatalog.ps1
```

`Connect-MmsApi` warns when the server version no longer matches the snapshot.
`Tests\Unit\ApiSurface.Tests.ps1` then names the routes that disappeared.

## Releasing

Release on a **tag**, not on every commit to the default branch: the PowerShell
Gallery refuses to replace a version that already exists, so `ModuleVersion` has
to increase for every publish.

```powershell
.\Tools\Build-MmsApiRelease.ps1 -OutputPath C:\Temp\release -WhatIf
.\Tools\Build-MmsApiRelease.ps1 -OutputPath C:\Temp\release
Publish-Module -Path C:\Temp\release\Neo42.MmsApi\<version> -NuGetApiKey <key>
```

`Publish-Module` packs the whole module folder, which is why the artifact is
staged first — otherwise the test suite and these notes end up on the Gallery.
The staged copy is verified before it is handed over: it must import on its own,
without a warning, and export exactly what the manifest declares.

## Related

- Example scripts that use this module: `..\API\`
- neo42 Management Service product documentation for what the plug-ins mean
