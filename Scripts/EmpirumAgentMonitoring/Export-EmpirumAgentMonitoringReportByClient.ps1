#requires -version 4
<#
.SYNOPSIS
    Export a single Empirum Agent Monitoring Report
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for a given client from Empirum Agent Monitoring to csv.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  13.08.2021
    Purpose/Change: Initial version
  
.EXAMPLE
    .\Export-EmpirumAgentMonitoringReportByClient.ps1 -Domain corp -ClientName client
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
$filename = "$($PSScriptRoot)\EmpirumReport.csv"

$clientByNameUrl = "$servername/api/clientbyname/$((New-Guid).Guid)?domainName=$($Domain)&computerName=$($ClientName)"
$empirumReportUrl = "$servername/api/empirummonitoringreport/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")

$client = Invoke-RestMethod -Method Get -Uri $clientByNameUrl -Headers $headers -UseDefaultCredentials

if($null -eq $client)
{
    Write-Warning "No client found for $($Domain)\$($ClientName)"
    Exit
}

$report = Invoke-RestMethod -Method Get -Uri $empirumReportUrl.Replace("{CLIENTID}","$($client.Id)") -Headers $headers -UseDefaultCredentials
$output = New-Object Collections.Generic.List[System.Object]
if($null -eq $report)
{
    Write-Warning "No empirum report found for $($Domain)\$($ClientName)"
    Exit
}

$obj = New-Object System.Object
$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
$obj | Add-Member -type NoteProperty -name ReportDate -value $report.Report.CollectionTime
$obj | Add-Member -type NoteProperty -name InventoryDate -value $report.EmpirumData.LastInvDateTime
$obj | Add-Member -type NoteProperty -name AdDate -value $report.AdData.LastContact
$obj | Add-Member -type NoteProperty -name ErisInstalled -value $report.Report.ErisInstalled
$obj | Add-Member -type NoteProperty -name ErisActive -value $report.Report.ErisActive
$obj | Add-Member -type NoteProperty -name ErisVersion -value $report.Report.Eris.Version
$obj | Add-Member -type NoteProperty -name UafInstalled -value $report.Report.UafInstalled
$obj | Add-Member -type NoteProperty -name UafActive -value $report.Report.UafActive
$obj | Add-Member -type NoteProperty -name UafVersion -value $report.Report.Uaf.Version
$obj | Add-Member -type NoteProperty -name UemVersion -value $report.Report.UemRelease
$obj | Add-Member -type NoteProperty -name RebootPending -value $report.Report.RebootPending
$output.Add($obj)

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default