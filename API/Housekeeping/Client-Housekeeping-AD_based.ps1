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
	Purpose/Change:	Align with new api and coding standards

.EXAMPLE
	.\Client-Housekeeping-AD_based.ps1 -ServerName "https://server.domain:4242"
.EXAMPLE
	.\Client-Housekeeping-AD_based.ps1 -ServerName "https://server.domain:4242" -ClientsToKeep "Example-Computer1","Example-Computer2"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $false)]
	[string[]]
	$ClientsToKeep = [string[]]@()
)

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
$url = "$ServerName/api/Client"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$clients = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials -ErrorAction Stop

foreach ($client in $clients) {
	#Remove Entries that cannot be found in AD, keep Clients listed on the blacklist $ClientsToKeep
	$CompObj = Get-Adcomputer -Filter "Name -eq `"$($client.Name)`"" -ErrorAction SilentlyContinue
	if (($null -eq $CompObj) -and ($ClientsToKeep -notcontains $client.Name)) {
		$deleteurl = "$ServerName/api/ServiceInfrastructureV3/$($client.Id)"
		Write-Verbose "Removing Client $($Client.Name)"
		Invoke-RestMethod -Method Delete -Uri $deleteurl -Headers $headers -UseDefaultCredentials
		Start-Sleep -Seconds 1
	}
}
