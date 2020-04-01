#Requires -Version 4
#+Requires -Modules ActiveDirectory (Added Advisory on Missing Module below)
<#
.SYNOPSIS
    Deletes clients from the MMS database that can not be found in Active Directory
.DESCRIPTION
    All clients that have not been added to the $ClientsToKeep Variable and can't be found in Active Directory
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
    Creation Date:  27.03.2020
    Purpose/Change: Initial version
  
.EXAMPLE
    .\Client-Housekeeping-AD_based.ps1
#>

# Fill with current servername
$servername = 'https://server.domain:443'
## Fill with Clients that should not be removed
$ClientsToKeep = @(
    "Example-Computer1",
    "Example-Computer2",
    "NotInDomainButMMSManaged"
)

# Testing for required Module
if (!(Get-Module -listavailable -Name Activedirectory)) {
    Write-Warning "
ActiveDirectory Module not available, please run this Script on a host with the ActiveDirectory Powershell Module installed. To install the ActiveDirectory Module on a Windows Server run the following command:`n
Add-WindowsFeature -Name `"RSAT-AD-PowerShell`" –IncludeAllSubFeature
`n
To install the ActiveDirectory Module on Windows 10 run the following command:`n
Enable-WindowsOptionalFeature -Online -FeatureName RSATClient-Roles-AD-Powershell
`n "
    break
}

# Get Clientlist from MMS Server
$url = "$servername/api/client"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$clients = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials

foreach ($client in $clients) {
    #Remove Entries that cannot be found in AD, keep Clients listed on the blacklist $ClientsToKeep
    $CompObj = Get-Adcomputer -Filter "Name -eq `"$($client.Name)`"" -ErrorAction SilentlyContinue
    if (!($CompObj) -and ($ClientsToKeep -notcontains $client.Name)) {
        $deleteurl = "$url/$($client.Id)"
        Write-Verbose "Removing Client $($Client.Name)"
        Invoke-RestMethod -Method Delete -Uri $deleteurl -Headers $headers -UseDefaultCredentials
        Start-Sleep -Seconds 1
    }
}
