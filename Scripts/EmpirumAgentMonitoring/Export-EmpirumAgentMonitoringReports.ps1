#requires -version 4
<#
.SYNOPSIS
    Exports all Empirum Agent Monitoring Reports
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for all known clients from Empirum Agent Monitoring Reports to csv.
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
    .\Export-EmpirumAgentMonitoringReports.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\EmpirumReports.csv"

$clientUrl = "$servername/api/client"
$empirumReportUrl = "$servername/api/empirummonitoringreport"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")

$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials
$rawreports = Invoke-RestMethod -Method Get -Uri $empirumReportUrl -Headers $headers -UseDefaultCredentials

$reports = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach($report in $rawreports)
{
    $reports.Add($report.Report.ClientId, $report)
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
}

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default