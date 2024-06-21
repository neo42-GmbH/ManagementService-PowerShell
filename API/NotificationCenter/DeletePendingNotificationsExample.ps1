<#
	.SYNOPSIS
		Examplescript for the Management Service NotificationCenter Module
		Deletes all pending notifications for all targets.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName
)
$PSDefaultParameterValues["*-MMS*:ServerName"] = $ServerName
Import-Module -Force $PSScriptRoot\NotificationCenter.psm1
$PSDefaultParameterValues["*-MMS*:ServerName"] = "mmsblazor.neo.dom"
Read-Host "This will delete all Pending Notifications for the Targets $TargetNames.
Press Enter to continue or CTRL+C to abort."
Remove-MMSPendingNotifications
