#requires -version 5
<#
.SYNOPSIS
	Exports all expired Notifications that were not received by the target.

#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName,
	[parameter(Mandatory = $true)]
	[System.IO.DirectoryInfo]
	$OutputPath
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName


$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "ExpiredNotReceivedNotifications.csv"

$targetType = @{
    0 = "Device"
    1 = "User"
}

$targets = Get-MmsNotificationCenterTarget
$notifications = Get-MmsNotification

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