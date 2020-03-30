#requires -version 4
<#
.SYNOPSIS
    Deletes clients from the MMS database
.DESCRIPTION
    All clients that did not update the 'Last contact' field for the last xx days (set by $dateRange)
    will be removed from the database. Caution: All plug-in reports for the clients will be removed!
    Can be used as a scheduled task to ensure a regular cleanup of the database.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  27.01.2020
    Purpose/Change: Initial version
  
.EXAMPLE
    .\Client-Housekeeping-LastContact_based.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'
# Delete clients with reports older then xx days
$dateRange = 60

$url = "$servername/api/client"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")
$clients = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials

foreach($client in $clients)
{
    if([DateTime]$client.LastAccess -lt ((Get-Date).AddDays(-$dateRange)))
    {
        $deleteurl = "$url/$($client.Id)"
        Invoke-RestMethod -Method Delete -Uri $deleteurl -Headers $headers -UseDefaultCredentials
        Start-Sleep -Seconds 1
    }
}