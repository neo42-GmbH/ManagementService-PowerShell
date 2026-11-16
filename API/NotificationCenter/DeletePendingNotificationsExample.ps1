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
# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName
Read-Host "This will delete all pending notifications of every target.
Press Enter to continue or CTRL+C to abort."
# -Confirm:$false because the Read-Host above is already the confirmation.
# Run the script with -WhatIf to see what would be deleted.
Remove-MmsPendingNotification -Confirm:$false
