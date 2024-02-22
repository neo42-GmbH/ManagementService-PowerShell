#Requires -Version 5
#+Requires -Modules SqlServer
<#
.SYNOPSIS
	Deletes clients from the MMS database that can not be found in Empirum
.DESCRIPTION
	All clients that have not been added to the $ClientsToKeep Variable and can't be found in Empirum
	will be removed from the database. Caution: All plug-in reports for the clients will be removed!
	Can be used as a scheduled task to ensure a regular cleanup of the database.
	Customize the $ClientsToKeep variable before use to protect specific computerobjects from deletion.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER ClientsToKeep
	An array of client names that should not be removed from the database.
.PARAMETER EmpirumDatabaseServer
	The servername of the Empirum Database in the format "Server\Instance".
.PARAMETER EmpirumDatabaseName
	The name of the Empirum Database.
.OUTPUTS
	none
.NOTES
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	29.11.2023
	Purpose/Change:	Align with new api and coding standards
.EXAMPLE
	.\Client-Housekeeping-Empirum_based.ps1 -ServerName "https://server.domain:4242" -EmpirumDatabaseServer "MY\Server" -EmpirumDatabaseName "EmpirumDB"
.EXAMPLE
	.\Client-Housekeeping-Empirum_based.ps1 -ServerName "https://server.domain:4242" -EmpirumDatabaseServer "MY\Server" -EmpirumDatabaseName "EmpirumDB" -ClientsToKeep "Example-Computer1","Example-Computer2"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $false)]
	[string[]]
	$ClientsToKeep = [string[]]@(),
	[parameter(Mandatory = $true)]
	[string]
	$EmpirumDatabaseServer,
	[parameter(Mandatory = $true)]
	[string]
	$EmpirumDatabaseName
)


# Testing for required Module
if ($null -eq (Get-Command -Name Invoke-Sqlcmd)) {
	Write-Warning "
SqlServer Module not available. To install the SqlServer Module run the following command:`n
Install-Module SqlServer"
	Start-Sleep 10
	exit 1
}

# Get Clientlist from MMS Server
$url = "$ServerName/api/Client"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$clients = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials -ErrorAction Stop

# Get Empirum Clientlist from Empirum DB
$query = "SELECT name,domain FROM Clients"
$empclients = Invoke-Sqlcmd -Query $query -ServerInstance $EmpirumDatabaseServer -Database $EmpirumDatabaseName | ForEach-Object { "$($_.domain)\$($_.name)" -replace " ", "" }
if ($empclients.Count -eq 0) {
	Write-Output "No Empirum clients in List, abort!"
	Start-Sleep 10
	exit 1
} 

foreach ($client in $clients) {
	#Remove entries that cannot be found in Empirum, keep Clients listed on the blacklist $ClientsToKeep
	if (
		($empclients -notcontains "$($client.domain)\$($client.name)") -and 
		($ClientsToKeep -notcontains $client.Name)
	) {
		$deleteurl = "$ServerName/api/ServiceInfrastructureV3/$($client.Id)"
		Write-Output "Removing Client $($client.domain)\$($client.name)"
		Invoke-RestMethod -Method Delete -Uri $deleteurl -Headers $headers -UseDefaultCredentials
	}
}
