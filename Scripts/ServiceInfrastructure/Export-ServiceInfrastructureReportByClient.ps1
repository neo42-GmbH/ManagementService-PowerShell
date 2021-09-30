#requires -version 4
<#
.SYNOPSIS
    Export a single Service Infrastructure Report
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for a given client from Service Infrastructure to csv.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  30.09.2021
    Purpose/Change: Initial version
  
.EXAMPLE
    .\Export-ServiceInfrastructureReportByClient.ps1 -Domain corp -ClientName client
#>
Param
  (
    [parameter(Mandatory=$true)]
    [String]
    $Domain,
    [parameter(Mandatory=$true)]
    [String]
    $ClientName
  )

# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\ServiceInfrastructureReport.csv"

$clientByNameUrl = "$servername/api/clientbyname/$((New-Guid).Guid)?domainName=$($Domain)&computerName=$($ClientName)"
$siReportUrl = "$servername/api/ServiceInfrastructureV2/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")

$client = Invoke-RestMethod -Method Get -Uri $clientByNameUrl -Headers $headers -UseDefaultCredentials

if($null -eq $client)
{
    Write-Warning "No client found for $($Domain)\$($ClientName)"
    Exit
}

$report = Invoke-RestMethod -Method Get -Uri $siReportUrl.Replace("{CLIENTID}","$($client.Id)") -Headers $headers -UseDefaultCredentials
$output = New-Object Collections.Generic.List[System.Object]
if($null -eq $report)
{
    Write-Warning "No Service Infrastructure report found for $($Domain)\$($ClientName)"
    Exit
}

$obj = New-Object System.Object
$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
$obj | Add-Member -type NoteProperty -name Domain -value $client.Domain
$obj | Add-Member -type NoteProperty -name IsOnline -value $report.IsOnline
$obj | Add-Member -type NoteProperty -name ClientVersion -value $report.Version
$obj | Add-Member -type NoteProperty -name LastContact -value $report.LastContact
$obj | Add-Member -type NoteProperty -name LastLogonUser -value $report.LastLogonUser
$obj | Add-Member -type NoteProperty -name LastLogonTime -value $($report.LogonEvents | Sort-Object -Property Time -Descending | Select-Object -First 1).Time
$output.Add($obj)

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default