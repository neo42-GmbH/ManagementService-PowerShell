#requires -version 5
<#
.SYNOPSIS
	Exports all certificate information from the Device Information plug-in

#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName,
	[Parameter(Mandatory = $false)]
	[string]
	$OutputPath = $PWD
)

$targetsUrl = "$ServerName/api/NotificationCenter/Target/All"
$notificationsUrl = "$ServerName/api/NotificationCenter/Notifications/All"

$filePath = Join-Path -Path $OutputPath -ChildPath "ExpiredNotReceivedNotifications.csv"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$targetType = @{
    0 = "Device"
    1 = "User"
}

$targets = Invoke-RestMethod -Method Get -Uri $targetsUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$notifications = Invoke-RestMethod -Method Get -Uri $notificationsUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

## Filter for expired, and has targets that did not receive
$notifications = $notifications | Where-Object { 
    $null -ne $_.Notification.ExpirationDate -and 
    (Get-Date -Date $_.Notification.ExpirationDate) -lt (Get-Date) -and
    $_.Targets.IsSent -contains $false
}

$output = @()
foreach ($notification in $notifications) {
    $missedTargetIds = $notification.Targets | Where-Object { $_.IsSent -eq $false } | Select-Object -ExpandProperty ClientId
    foreach ($id in $missedTargetIds) {
        $matchingTarget = $targets | Where-Object { $_.ClientIds -contains $id } | Select-Object -First 1
        $output += [PSCustomObject]@{
            notificationId = $notification.Notification.Id
            notificationCreated = $notification.Notification.Message.CreationDate
            notificationGroup = $notification.Notification.Message.NotificationGroup
            targetId = $id
            targetName = $matchingTarget.Name
            targetType = $targetType[$matchingTarget.Type]
        }
    }
}

$output | Export-Csv -Path $filePath -NoTypeInformation