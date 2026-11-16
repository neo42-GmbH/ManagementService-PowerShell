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
# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

$targets = Get-MmsNotificationCenterTarget | Where-Object { $_.Name -in $TargetNames }
$clientID = $targets.ClientIds | Select-Object -First 1
$Notifications = Get-MMSNotification -ClientID $clientID
Read-Host "This will delete all Notifications for the Targets $TargetNames.
This will also delete the Notifications for all other Targets that received the same Notifications.
Press Enter to continue or CTRL+C to abort."
$Notifications | ForEach-Object {
	Remove-MMSNotification -NotificationGuid $_.Notification.Id -Verbose
}