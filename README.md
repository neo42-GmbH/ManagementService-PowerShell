# ManagementService-PowerShell

PowerShell scripts that can support you to automate tasks with the 'neo42 Management Service'.

## Neo42.MmsApi module

Everything in `API\` talks to the MMS through the **`Neo42.MmsApi`** module in
this repository. It handles the connection, authentication, error messages and
`-WhatIf`, so an example script only expresses what it wants:

```powershell
Import-Module .\Neo42.MmsApi\Neo42.MmsApi.psd1

Connect-MmsApi -ServerName 'https://server.domain:4242'

Get-MmsClient | Format-Table Name, Domain, IsOnline, LastAccess
Get-MmsBitLockerReport | Format-Table ClientID, ComplianceState, EncryptionPercentage
```

It is one module for the whole API. The plug-ins are separated by the command
noun, so you can list just the part you are licensed for:

```powershell
Get-Command -Module Neo42.MmsApi -Noun MmsApc*        # Application Package Center
Get-Command -Module Neo42.MmsApi -Noun MmsBitLocker*  # BitLocker plug-in
Get-Command -Module Neo42.MmsApi                      # everything
```

See [`Neo42.MmsApi/README.md`](Neo42.MmsApi/README.md) for the function list, the
session and authentication model, and the response shapes the API uses.

### Running the examples

The scripts keep their original parameters (`-ServerName`, `-OutputPath`, …) and
prefer an installed `Neo42.MmsApi` module, falling back to the copy in this
repository — so a fresh clone works without installing anything:

```powershell
.\API\BitLocker\Export-BitlockerReports.ps1 -ServerName 'https://server.domain:4242' -OutputPath C:\Temp
```

Scripts that change or delete something support `-WhatIf`. Use it first:

```powershell
.\API\Housekeeping\Client-Housekeeping-LastContact_based.ps1 -ServerName 'https://server.domain:4242' -RemoveAfterDays 90 -WhatIf
```

To have the module available in every session, run the installer:

```powershell
.\Neo42.MmsApi\Tools\Install-MmsApiModule.ps1 -WhatIf   # shows where it would go
.\Neo42.MmsApi\Tools\Install-MmsApiModule.ps1
```

It installs the release copy — module, help and the API snapshot, without the
test suite — into `Documents\WindowsPowerShell\Modules\Neo42.MmsApi\<version>\`.
Use `-Scope AllUsers` for the machine wide path, which needs an elevated session.
Remove it again by deleting that folder.

## Further Information

For further information about the neo42 Management Service please check our
website https://neo42.de or visit our YouTube channel
https://www.youtube.com/user/neo42gmbh
