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
	Purpose/Change:	Handle empty LastAccess property.
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
		[uri]$deleteUrl = "$ServerName/api/ServiceInfrastructureV3/$($client.Id)"
		Write-Host "Deleting $($client.Name) with ID $($client.Id) because of last contact at $($lastContact)"
		Invoke-RestMethod -Method Delete -Uri $deleteUrl -Headers $headers -UseDefaultCredentials
		Start-Sleep -Milliseconds 100
	}
}