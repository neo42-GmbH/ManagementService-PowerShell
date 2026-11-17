# Tests

Test suite for `Neo42.MmsApi`, built with **Pester 6** on Windows PowerShell 5.1.

What it is for, in this order of importance:

1. **Spot the breaking changes of a new MMS version** — before they show up at a
   customer.
2. **Catch regressions in the module** — so an addition does not take something
   existing apart.
3. **Trust the write paths** — reproducibly, instead of once by hand.

## Getting started

```powershell
# Offline, needs nothing. This is the run before every commit.
.\Invoke-MmsTests.ps1

# Read-only against the server named in the configuration
.\Invoke-MmsTests.ps1 -Scope Integration

# Writing, only against a system declared a lab
.\Invoke-MmsTests.ps1 -Scope Write

# One file, while you are writing it
.\Invoke-MmsTests.ps1 -Path .\Unit\Test-MmsShouldProcess.Tests.ps1 -Output Detailed
```

Install Pester 6 if it is missing:

```powershell
Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
```

On a PS 5.1 machine without the NuGet provider, fetch the package from the
Gallery and unpack it instead:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest 'https://www.powershellgallery.com/api/v2/package/Pester/6.1.0' -OutFile "$env:TEMP\pester.zip"
Expand-Archive "$env:TEMP\pester.zip" -DestinationPath "$HOME\Documents\WindowsPowerShell\Modules\Pester\6.1.0"
```

Pester 6.1.0 declares `PowerShellVersion = '5.1'` and ships `bin\net462`, so it
runs without PowerShell 7.

### Reading the results

`-Output Normal` (the default) prints one line per **file**; `-Output Detailed`
lists every test. Skipped tests are listed with their reason at the end — "green
with 40 skips" means almost nothing was verified.

Nothing is exported unless you ask:

```powershell
.\Invoke-MmsTests.ps1 -Scope Integration -ResultPath .\TestResults\integration.xml
```

That writes NUnit XML, and `TestResults\` is gitignored for it — the file embeds
the machine name, the user domain and the working directory along with whatever
was read from the server. The runner warns when you ask for one.

For something readable, take the result object instead:

```powershell
$r = .\Invoke-MmsTests.ps1 -Scope Integration -PassThru
$r | Select-Object Result, PassedCount, FailedCount, SkippedCount, Duration
$r.Failed | Select-Object ExpandedPath
```

`-PassThru` is meant to be captured into a variable; left on the pipeline it
prints the whole object graph.

## Configuring the test system

`mms.tests.config.psd1` in this folder; the template with every option is
`mms.tests.config.example.psd1`. Copy, fill in, done.

The file is **written by hand and never generated**. The suite reads it as it
stands, writes nothing back and does not create it. It is gitignored, because it
names a concrete server. A different path goes through `NEO42_MMS_TEST_CONFIG`.

Without the file only the unit tests run; Integration and Write report
themselves as skipped, with the reason.

Three independent switches protect the write paths, and all three have to be
open:

| Switch | Meaning |
| --- | --- |
| `IsLab = $true` | The data of this server may be changed. |
| `Write.Enabled = $true` | Write tests are wanted. |
| `Write.DeletableClientNames` | A list of names. Only these clients may be deleted. |

An empty `DeletableClientNames` means: delete nothing. Put a client on it only
if it re-registers afterwards and its history is expendable.

## Folders

```
Tests\
  Invoke-MmsTests.ps1              entry point
  mms.tests.config.example.psd1    template (in the repository)
  mms.tests.config.psd1            your own configuration (not in the repository)
  TestHelpers\MmsTestContext.ps1   module import and reading the configuration
  TestHelpers\ConfirmProbe.ps1     the -Confirm case, run as a child process
  Unit\                            offline, without a server
  Integration\                     read-only against a server
  Write\                           writing, opt-in, lab only
```

The folder decides the level and the `-Tag` on the `Describe` repeats it, so a
file that ends up in the wrong folder still cannot run in a scope it does not
belong to.

## Rules for new tests

Keep the numbering — other files reference these rules by number.

1. **Every "nothing happened" assertion needs a control.** A test that checks no
   request goes out is just as green when the call already failed on a
   misspelled parameter name. Always in pairs: one case proving the same call
   **without** suppression produces exactly one request, and one that suppresses
   it. Mocking a command inside a module scope needs
   `function script:<Name>`, not a plain `function`, or the mock never takes.
2. **Unit tests do not touch a server.** The transport is mocked in the module
   scope: `Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith { }`.
   That covers route building, query encoding, headers, envelopes and the whole
   `-WhatIf` mechanism. Private functions are reachable with
   `InModuleScope Neo42.MmsApi { ... }`, parameters through `-Parameters @{ ... }`
   plus `param(...)` in the block.
3. **Write tests only touch what they created themselves**, and clean up in
   `AfterAll`, not at the end of the last `It` — a test failing mid-chain must
   not leave the server dirty. Record created ids in a script variable as soon
   as they exist. A lifecycle chain (create → read → delete) may be
   order-dependent inside **one** `Context`; that is the only exception.
4. **Missing data is a skip with a reason, not a failure.** A plug-in without a
   license or without reports is not a defect of the module:
   `Set-ItResult -Skipped -Because 'this server has no BitLocker reports'`. It
   unwinds the `It`, so a following dereference is safe. A wrong configuration —
   a `ClientName` that does not exist — is a failure.
5. **Never assert a value you would not want to see in a log.** A failed
   assertion prints its input into the console and every result file. For a
   recovery key, check presence and type, never the key. Same for credentials
   and tokens. Likewise do not pipe large files into an assertion; extract the
   value first.
6. **A `-ForEach` key must not be named like an automatic variable.**
   `@{ input = 'host' }` silently does not take. Burnt: `input`, `args`,
   `matches`, `error`, `host`, `this`, `_`. Use `ServerName`, `Value`, `Given`.
7. **`-ForEach` data is created at discovery time.** `BeforeAll` runs too late —
   tables belong in `BeforeDiscovery` or directly on the `It`. Scriptblocks in
   such tables must be self-sufficient (literal ids, no outer variables).
   The converse is just as sharp: a variable assigned in `BeforeDiscovery` is
   **not** visible inside an `It`. A list an `It` walks at run time has to be
   built in `BeforeAll` as well — `foreach ($x in $script:listFromDiscovery)`
   silently loops over nothing and the case can never fail.
8. **Static and behavioural checks complement each other.**
   `Unit\Module.Hygiene.Tests.ps1` uses the AST to check that no function calls
   `Invoke-RestMethod` directly and that every function sending a non-GET
   request uses `Test-MmsShouldProcess` — which catches a **new** function
   nobody wrote a behavioural case for. Deliberately not filtered by verb: what
   matters is the method on the wire, not the name. AST and not regex, because
   several helpers mention `Invoke-RestMethod` in their help.
9. **A destructive path is tested against an invented id.** The `-WhatIf` proof
   for `Remove-MmsClient` in `Integration\ErrorPaths.Tests.ps1` runs against a
   fresh GUID: if `-WhatIf` works no request goes out, and if it were broken the
   request hits nothing, returns 404 and fails loudly. Both ways are safe, which
   is the condition for testing a delete path against a server at all.
10. **An `It` name describes behaviour.** "sends nothing when a wrapping script
    runs with -WhatIf", not "test 4" — the name is often the only thing anyone
    reads. Everything in this repository is written in English, code comments
    included.
11. **A missing mandatory parameter does not throw, it asks.**
    `{ Get-MmsDeviceInformation } | Should -Throw` hangs the suite: PowerShell
    prompts during parameter binding, before the command runs, so
    `-ErrorAction Stop` does not help. Test the reason instead — that the
    **server** rejects the route without the parameter — in
    `Integration\ReadContract.Tests.ps1` through `Invoke-MmsApiRequest`. Mixing
    two parameter sets does throw cleanly and belongs at the unit level;
    `-ErrorId` wants the whole `FullyQualifiedErrorId`, command name included
    (`'AmbiguousParameterSet,Get-MmsDeviceInformation'`). The same applies to
    `ShouldContinue`, where the default answer is **Yes** — such cases run in a
    `powershell.exe -NonInteractive` child process
    (`TestHelpers\ConfirmProbe.ps1` is the template), and `-NonInteractive` is
    passed explicitly rather than inherited. **Consequence: a green run in a
    non-interactive shell says nothing about the console.** Start the suite by
    hand in a real console at least once.
12. **`Out-String` wraps at console width.** `... 6>&1 | Out-String` breaks a
    `What if:` line mid-text as soon as the window is narrower than the message,
    so an assertion matching further into the line is green on a wide monitor
    and red in a narrow terminal. Always `Out-String -Width 500`.
13. **Two tests that find the same thing are one too many**, and a test that
    cannot fail is not a test. Demonstrate rather than argue: copy the module
    into a temp directory, build the fault in artificially and see which cases
    fire. The same technique applies to an assertion you already have — change
    the code under test so it *should* fail, and check that it does.

14. **Five ways a case is green for the wrong reason.** Every one of these was
    found in this suite by the technique in rule 13, so check for them before
    trusting a new assertion:

    - `@($help.Examples.Example).Count` is **1** when there is no example at
      all: `@($null)` has one element. Anything that counts a possibly null
      expression has to drop the nulls first — `@(... | Where-Object { $_ })`.
    - `-WarningVariable` does not see a warning a module writes **while it is
      being imported**: the module scope carries its own `$WarningPreference`.
      Capture stream 3 instead (`Import-Module ... 3>&1`).
    - `Write-Verbose` inside the module obeys the module's `$VerbosePreference`
      and not the `-Verbose` of a calling script — the same scope gap that makes
      `Test-MmsShouldProcess` necessary. A case that reads the verbose request
      line as evidence has to raise that preference inside the module first.
    - The undocumented-route warning is raised **once per route and session**.
      A case that asserts on it has to empty
      `$script:MmsUndocumentedRouteWarnings` first, otherwise the result depends
      on what ran before it.
    - `Should -Be` compares case insensitively. `'https://x' | Should -Be
      'HTTPS://x'` passes; pinning the casing needs `Should -BeExactly`.

## The reference test

`Unit\Test-MmsShouldProcess.Tests.ps1` is the template new tests should follow.
It covers the most dangerous behaviour of the module — a function exported from
a module runs in module scope and does **not** inherit `$WhatIfPreference` from
the calling script, so a script started with `-WhatIf` can delete for real — and
demonstrates every technique in the suite along the way: a `BeforeDiscovery`
table, a module-scoped mock, controls, data-driven cases across all write
functions, output checks, and a child process for the case that cannot be
observed in-process.

## Breaking change detection

`Unit\ApiSurface.Tests.ps1` holds the list of every route the module uses and
checks it against `..\docs\swagger-v1.json`. After refreshing the snapshot
against a new MMS version, that file says which wrapper a server-side change has
just taken apart.

The table is written out, but it cannot go stale: two cases pull the routes out
of `Public\` by AST and compare in both directions, so a new endpoint nobody
entered turns the run red — **when you add an endpoint, the route belongs in
there.** `the module wraps published routes only` then asserts that every route
in the table is in the snapshot, and names all offenders at once when one is
not. There is no exception list: a route swagger does not publish is out of
scope for the module, so a wrapper on one fails the suite.

`Integration\Connection.Tests.ps1` checks whether the server version still
matches the version of the snapshot. If that fails, the snapshot is due.

### Field contract

`Integration\ReadContract.Tests.ps1` checks the fields that the module and the
example scripts actually dereference. What matters is less the names than the
nesting — the Empirum report keeps its ClientId in `Report.ClientId`, the others
directly in `ClientId`:

| Wrapper | Path to the ClientId | other checked fields |
| --- | --- | --- |
| `Get-MmsClient` | `Id` | `Name`, `Domain`, `NetBiosName`, `IsOnline`, `LastAccess` |
| `Get-MmsBitLockerReport` | `ClientId` | `ComplianceState`, `EncryptionPercentage`, `Disks` |
| `Get-MmsDeviceInformation -Type 'cert'` | `Id` | `OperatingSystem.CertificateStores` |
| `Get-MmsDeviceInformation -Type 'os'` | `Id` | `OperatingSystem.Groups` (`.User`, `.Groups`) |
| `Get-MmsDriveMonitoringReport` | `ClientId` | `VolumeInfos`, `CurrentThresholdSize` |
| `Get-MmsMaintenanceRebootReport` | `ClientId` | `AutoRebootState`, `EventList` |
| `Get-MmsEmpirumMonitoringReport` | `Report.ClientId` | `Report.UafActive`, `EmpirumData`, `AdData` |
| `Get-MmsServiceInfrastructureReport` | `ClientId` | `Name`, `IsOnline`, `LastContact`, `LastLogonUser` |
| `Get-MmsNotification` | `Targets[].ClientId` | `Notification.Id` |
| `Get-MmsNotificationCenterTarget` | `ClientIds` | `Name`, `Type` |
| `Get-MmsApcPipeline` | — | `Id` (24 hex), `Name`, `Enabled` |
| `Get-MmsApcPipelineRun` | — | `RunId`, `State`, `StartTime`, `StateName` |
| `Get-MmsApcPackageInfo` | — | `Id`, `AppName`, `AppVendor` |
| `Get-MmsFilter -ExpandCriteria` | — | `Id`, `Criteria`, `CriteriaObject.Name` |

Keep this table up to date with every new wrapper — it is the contract an MMS
update can break.

For `Get-MmsDeviceInformation` the `-Type` is part of the contract: an unknown
area is **not** an error, the server answers with an all-null record. A test
that only asserts `Id` would therefore be green for a typo in the type as well,
so the assertion has to hit the sub object the type is supposed to fill.

Everything that supports it is read with `-Limit 1`. One row proves the shape
just as well as 8000, and a suite nobody waits for is a suite nobody runs.

## What the write tests touch

| File | Creates | Cleans up |
| --- | --- | --- |
| `Write\Notification.Tests.ps1` | a notification for the configured client | deletes it again |
| `Write\Pipeline.Tests.ps1` | a run of the configured pipeline | deletes the run record |
| `Write\Client.Tests.ps1` | nothing | nothing — only deletes what is in `DeletableClientNames` |

The side effect of the pipeline itself — a package downloaded onto the server —
is not taken back, so the configured pipeline has to be one where that costs
nothing: a download or a report, never a productive import.

Deliberately **not** in the write tests: `Remove-MmsPendingNotification` (acts
globally), `Start-MmsApcEmpCleanupJob` (deletes packages),
`Start-MmsApcPackageSync` (server load) and any productive pipeline.

## Procedure for checking a new MMS version

1. `.\Invoke-MmsTests.ps1` — offline, has to be green every time
2. `..\Tools\Update-MmsApiCatalog.ps1` against the new server
3. `.\Invoke-MmsTests.ps1` again — `ApiSurface.Tests.ps1` now names the routes
   that no longer exist
4. `.\Invoke-MmsTests.ps1 -Scope Integration` — field contract and error paths
5. `.\Invoke-MmsTests.ps1 -Scope Write` deliberately, and only in a lab
