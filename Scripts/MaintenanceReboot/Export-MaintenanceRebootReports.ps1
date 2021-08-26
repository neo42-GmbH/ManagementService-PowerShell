#requires -version 4
<#
.SYNOPSIS
    Exports all Drive Monitoring Reports
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for all known clients from Drive Monitoring Reports to csv.
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
    .\Export-MaintenanceRebootReports.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\MaintenanceRebootReports.csv"

$clientUrl = "$servername/api/client"
$maintenanceRebootReportUrl = "$servername/api/MaintenanceReport"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")

$headersv3=New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headersv3.Add("X-Neo42-Auth", "Admin")
$headersv3.Add("X-Neo42-ControllerVersion", "3")

$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials
$rawreports = Invoke-RestMethod -Method Get -Uri $maintenanceRebootReportUrl -Headers $headersv3 -UseDefaultCredentials

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
    $obj | Add-Member -type NoteProperty -name ReportDate -value $report.CreatedOn
    $obj | Add-Member -type NoteProperty -name LastRebootEvent -value $report.LastRebootEvent
    $obj | Add-Member -type NoteProperty -name ClientLocked -value $report.ClientLocked
    $obj | Add-Member -type NoteProperty -name CurrentRevokeCount -value $report.CurrentRevokeCount

    $output.Add($obj)
}

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default