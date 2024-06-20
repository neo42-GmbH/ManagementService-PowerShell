<#
	.SYNOPSIS
		Examplescript for the Management Service NotificationCenter Module
		Deletes all Notifications for the specified Targets.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[string[]]
	$TargetNames,
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName
)
Import-Module -Force $PSScriptRoot\NotificationCenter.psm1
$PSDefaultParameterValues["*-MMS*:ServerName"] = $ServerName
$targets = Get-MMSNotificationCenterTargets | Where-Object {$_.Name -in $TargetNames }
$clientID = $targets.ClientIds | Select-Object -First 1
$Notifications = Get-MMSNotification -ClientID $clientID
Read-Host "This will delete all Notifications for the Targets $TargetNames.
This will also delete the Notifications for all other Targets that received the same Notifications.
Press Enter to continue or CTRL+C to abort."
$Notifications | ForEach-Object {
	Remove-MMSNotification -NotificationGuid $_.Notification.Id -Verbose
}