#Requires -Version 5
#+Requires -Modules ActiveDirectory (Added Advisory on Missing Module below)
<#
.SYNOPSIS
	Deletes clients from the MMS database that can not be found in Active Directory
.DESCRIPTION
	All clients that have not been added to the $ClientsToKeep Variable and can't be found in Active Directory
	will be removed from the database. Caution: All plug-in reports for the clients will be removed!
	Can be used as a scheduled task to ensure a regular cleanup of the database.
	Customize the $ClientsToKeep variable before use to protect specific computerobjects from deletion.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER ClientsToKeep
	An array of client names that should not be removed from the database.
.OUTPUTS
	none
.NOTES
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	29.11.2023
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod

.EXAMPLE
	.\Client-Housekeeping-AD_based.ps1 -ServerName "https://server.domain:4242"
.EXAMPLE
	.\Client-Housekeeping-AD_based.ps1 -ServerName "https://server.domain:4242" -ClientsToKeep "Example-Computer1","Example-Computer2"
#>
[CmdletBinding(SupportsShouldProcess)]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $false)]
	[string[]]
	$ClientsToKeep = [string[]]@()
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

# Testing for required Module
if ($null -eq (Get-Module -listavailable -Name Activedirectory)) {
	Write-Warning "
ActiveDirectory Module not available, please run this Script on a host with the ActiveDirectory Powershell Module installed. To install the ActiveDirectory Module on a Windows Server run the following command:`n
Add-WindowsFeature -Name `"RSAT-AD-PowerShell`" –IncludeAllSubFeature
`n
To install the ActiveDirectory Module on Windows 10 run the following command:`n
Enable-WindowsOptionalFeature -Online -FeatureName RSATClient-Roles-AD-Powershell
`n "
	exit 1
}

# Get Clientlist from MMS Server
$clients = Get-MmsClient

foreach ($client in $clients) {
	#Remove Entries that cannot be found in AD, keep Clients listed on the blacklist $ClientsToKeep
	$CompObj = Get-Adcomputer -Filter "Name -eq `"$($client.Name)`"" -ErrorAction SilentlyContinue
	if (($null -eq $CompObj) -and ($ClientsToKeep -notcontains $client.Name)) {
		Write-Verbose "Removing Client $($Client.Name)"
		# -Confirm:$false because this script is meant to run unattended as a
		# scheduled task. Run it once with -WhatIf to see what it would delete.
		Remove-MmsClient -ClientId $client.Id -Confirm:$false
		# Give the server a moment between deletions.
		Start-Sleep -Seconds 1
	}
}
