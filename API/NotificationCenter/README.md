# Management Service NotificationCenter Powershell Examples

## These Scripts are examples of how to use the Management Service NotificationCenter Api with PowerShell.

All scripts use the `Neo42.MmsApi` module from the root of this repository. They
prefer an installed copy of the module and fall back to the one in the
repository, so a fresh clone works without installing anything — just pass
`-ServerName`.

### Reporting scripts

* `Get-ExpiredNotReceivedNotifications.ps1` — expired notifications that a target never received
* `Get-TargetNotificationReport.ps1` — delivery state of every notification of one target

### Scripts that change something

These ask for confirmation before they act. Add `-WhatIf` to any of them to see
what would happen without doing it.

* `Send-NotificationExamples.ps1` — demo sequence of the available themes, sounds, positions and banners
* `DeleteNotificationsExample.ps1` — deletes all notifications of the given targets
* `DeletePendingNotificationsExample.ps1` — deletes all pending notifications of every target

### Example

```powershell
.\Get-TargetNotificationReport.ps1 -ServerName "https://server.domain:4242" -TargetName "CLIENT1" -OutputPath "C:\Temp"

.\DeletePendingNotificationsExample.ps1 -ServerName "https://server.domain:4242" -WhatIf
```

`Icon.png` in this folder is the example icon used by `Send-NotificationExamples.ps1`.
