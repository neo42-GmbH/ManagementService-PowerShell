#requires -version 4
<#
.SYNOPSIS
    List all known Clients, their Last Contact and Last known Logon User
.DESCRIPTION
    Exports all known Clients and their last Logon User to a csv file.
    The data is based on the reports of the Service Infrastructure plug-in.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  04.11.2020
    Purpose/Change: Initial version
  
.EXAMPLE
    .\List-LastLogonUser.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\LastLogonUsers.csv"

$clientUrl = "$servername/api/client"
$siURL = "$servername/api/ServiceInfrastructureV2"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")
$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials
$rawreports = Invoke-RestMethod -Method Get -Uri $SiUrl -Headers $headers -UseDefaultCredentials

$reports = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach($report in $rawreports)
{
    $reports.Add($report.ClientId, $report)
}

$output = New-Object Collections.Generic.List[System.Object]
foreach($client in $clients)
{
    $report = $reports[$($client.Id)]
    if($null -eq $report)
    {
        continue
    }
        $obj = New-Object System.Object
        $obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
        $obj | Add-Member -type NoteProperty -name Domain -value $client.Domain
        $obj | Add-Member -type NoteProperty -name IsOnline -value $report.IsOnline
        $obj | Add-Member -type NoteProperty -name LastLogonUser -value $report.LastLogonUser
        $obj | Add-Member -type NoteProperty -name LastContact -value $report.LastContact
        $output.Add($obj)
}

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default