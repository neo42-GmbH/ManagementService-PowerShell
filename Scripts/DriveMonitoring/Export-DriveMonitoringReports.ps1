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
    .\Export-DriveMonitoringReports.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\DriveMonitoringReports.csv"

$clientUrl = "$servername/api/client"
$driveMonitoringReportUrl = "$servername/api/drivemonitoringreport"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")

$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials
$rawreports = Invoke-RestMethod -Method Get -Uri $driveMonitoringReportUrl -Headers $headers -UseDefaultCredentials

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
    $belowThreshold = $true
    if($report.CurrentThresholdSize -gt $report.VolumeInfos."<Freespace>k__BackingField")
    {
        $belowThreshold = $false
    }

    $obj = New-Object System.Object
    $obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
    $obj | Add-Member -type NoteProperty -name ReportDate -value $report.CreationDate
    $obj | Add-Member -type NoteProperty -name DeviceId -value $report.VolumeInfos."<DeviceId>k__BackingField"
    $obj | Add-Member -type NoteProperty -name VolumeName -value $report.VolumeInfos."<VolumeName>k__BackingField"
    $obj | Add-Member -type NoteProperty -name Freespace -value $report.VolumeInfos."<Freespace>k__BackingField"
    $obj | Add-Member -type NoteProperty -name Threshold -value $report.CurrentThresholdSize
    $obj | Add-Member -type NoteProperty -name BelowThreshold -value $belowThreshold

    $output.Add($obj)
}

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default