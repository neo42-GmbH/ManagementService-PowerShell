#Requires -Version 4
#+Requires -Modules SqlServer
<#
.SYNOPSIS
    Deletes clients from the MMS database that can not be found in Empirum
.DESCRIPTION
    All clients that have not been added to the $ClientsToKeep Variable and can't be found in Empirum
    will be removed from the database. Caution: All plug-in reports for the clients will be removed!
    Can be used as a scheduled task to ensure a regular cleanup of the database.
    Customize the $ClientsToKeep variable before use to protect specific computerobjects from deletion.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  04.05.2021
    Purpose/Change: Initial version
  
.EXAMPLE
    .\Client-Housekeeping-Empirum_based.ps1
#>

# Fill with current servername
$servername = 'https://server.domain:443'

# Fill with Empirum Sql Server Name
$empdbserver = "Server\Instance"
$empdatabase = "DBNAME"

# Fill with Clients that should not be removed
$ClientsToKeep = @(
    "Example-Computer1",
    "Example-Computer2",
    "NotInEmpirumButMMSManaged"
)

# Testing for required Module
if (!(Get-Command -Name Invoke-Sqlcmd)) {
    Write-Warning "
    SqlServer Module not available. To install the SqlServer Module run the following command:`n
    Install-Module SqlServer"
    Start-Sleep 10
    break
}

# Get Clientlist from MMS Server
$url = "$servername/api/client"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$clients = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials

# Get Empirum Clientlist from Empirum DB
$query = "SELECT name,domain FROM Clients"
$empclients = Invoke-Sqlcmd -Query $query -ServerInstance $empdbServer -Database $empdatabase | ForEach-Object { "$($_.domain)\$($_.name)" -replace " ", "" }
if ($empclients.Count -eq 0){
    Write-Output "No Empirum clients in List, abort!"
    Start-Sleep 10
    break
} 

foreach ($client in $clients) {
    #Remove entries that cannot be found in Empirum, keep Clients listed on the blacklist $ClientsToKeep
    if (($empclients -notcontains "$($client.domain)\$($client.name)") -and 
        ($ClientsToKeep -notcontains $client.Name)){
        $deleteurl = "$url/$($client.Id)"
        Write-Output "Removing Client $($client.domain)\$($client.name)"
        Invoke-RestMethod -Method Delete -Uri $deleteurl -Headers $headers -UseDefaultCredentials
    }
}
