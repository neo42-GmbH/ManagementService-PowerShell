#requires -version 5
<#
.SYNOPSIS
	Deletes clients from the MMS database
.DESCRIPTION
	All clients that did not update the 'Last contact' field for the last xx days (set by $dateRange)
	will be removed from the database. Caution: All plug-in reports for the clients will be removed!
	Can be used as a scheduled task to ensure a regular cleanup of the database.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER RangeInDays
	The number of days to keep clients in the database.
.OUTPUTS
	none
.NOTES
	Version:		1.2
	Author:			neo42 GmbH
	Creation Date:	30.08.2024
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Client-Housekeeping-LastContact_based.ps1 -ServerName "https://server.domain:4242" -RemoveAfterDays 90
#>
[CmdletBinding(SupportsShouldProcess)]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $true)]
	[int]
	$RemoveAfterDays
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

$clients = Get-MmsClient

foreach ($client in $clients) {
    if ($false -eq [string]::IsNullOrEmpty($client.LastAccess)) {
        [DateTime]$lastContact = $client.LastAccess
    } 
    elseif ($false -eq [string]::IsNullOrEmpty($client.CreationDate)) {
        [DateTime]$lastContact = $client.CreationDate
    }
    else {
        Write-Error $client.Name + " cannot be deleted because its last access time cannot be determined. Manual fix is required."
		continue
    }
	if ($lastContact -lt ((Get-Date).AddDays(-$RemoveAfterDays))) {
		Write-Host "Deleting $($client.Name) with ID $($client.Id) because of last contact at $($lastContact)"
		# -Confirm:$false because this script is meant to run unattended as a
		# scheduled task. Run it once with -WhatIf to see what it would delete.
		Remove-MmsClient -ClientId $client.Id -Confirm:$false
		# Give the server a moment between deletions.
		Start-Sleep -Milliseconds 100
	}
}