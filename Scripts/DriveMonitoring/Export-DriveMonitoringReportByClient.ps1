#requires -version 4
<#
.SYNOPSIS
    Export a single Drive Monitoring Report
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for a given client from Drive Monitoring to csv.
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
    .\Export-DriveMonitoringReportByClient.ps1 -Domain corp -ClientName client
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
$filename = "$($PSScriptRoot)\DriveMonitoringReport.csv"

$clientByNameUrl = "$servername/api/clientbyname/$((New-Guid).Guid)?domainName=$($Domain)&computerName=$($ClientName)"
$driveMonitoringReportUrl = "$servername/api/drivemonitoringreport/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")

$client = Invoke-RestMethod -Method Get -Uri $clientByNameUrl -Headers $headers -UseDefaultCredentials

if($null -eq $client)
{
    Write-Warning "No client found for $($Domain)\$($ClientName)"
    Exit
}

$report = Invoke-RestMethod -Method Get -Uri $driveMonitoringReportUrl.Replace("{CLIENTID}","$($client.Id)") -Headers $headers -UseDefaultCredentials
$output = New-Object Collections.Generic.List[System.Object]
if($null -eq $report)
{
    Write-Warning "No drive monitoring report found for $($Domain)\$($ClientName)"
    Exit
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

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default