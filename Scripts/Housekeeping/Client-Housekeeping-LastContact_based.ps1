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
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	29.11.2023
	Purpose/Change:	Align with new api and coding standards
.EXAMPLE
	.\Client-Housekeeping-LastContact_based.ps1 -ServerName "https://server.domain:4242" -RemoveAfterDays 90
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $true)]
	[int]
	$RemoveAfterDays
)

$url = "$ServerName/api/Client"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$clients = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials -ErrorAction Stop

foreach ($client in $clients) {
	if ([DateTime]$client.LastAccess -lt ((Get-Date).AddDays(-$RemoveAfterDays))) {
		$deleteurl = "$url/$($client.Id)"
		Invoke-RestMethod -Method Delete -Uri $deleteurl -Headers $headers -UseDefaultCredentials
		Start-Sleep -Seconds 1
	}
}