#requires -version 5
<#
.SYNOPSIS
	Exports the state of all notifications of a specific target.

#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName,
    [Parameter(Mandatory = $true)]
	[string]
	$TargetName,
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


$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "ClientNotificationReport.csv"

$targets = Get-MmsNotificationCenterTarget

$target = $targets | Where-Object { $_.Name -eq $TargetName }
if ($null -eq $target) {
    throw "$TargetName was not found"
}

# Get-MmsNotification -ClientId returns { Notification, Targets } entries, so the
# per target delivery state is already included and no second lookup per
# notification is needed.
$notifications = @()
foreach ($clientId in $target.ClientIds) {
    $notifications += Get-MmsNotification -ClientId $clientId
}

$output = @()
foreach ($entry in $notifications) {
    $targetInfo = $entry.Targets | Where-Object { $_.ClientId -in $target.ClientIds } | Select-Object -First 1

    $output += [PSCustomObject]@{
        notificationId = $entry.Notification.Id
        notificationCreated = $entry.Notification.Message.CreationDate
        notificationGroup = $entry.Notification.Message.NotificationGroup
        notificationSent = $targetInfo.IsSent
        notificationSentDate = $targetInfo.SentTime
        notificationReceivedDate = $targetInfo.ReceivedTime
        targetId = $targetInfo.ClientId
        targetName = $target.Name
    }
}

$output | Export-Csv -Path $filePath -NoTypeInformation