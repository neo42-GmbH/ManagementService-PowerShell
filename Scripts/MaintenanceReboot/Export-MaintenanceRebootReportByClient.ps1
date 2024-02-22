#requires -version 5
<#
.SYNOPSIS
	Export a single Drive Monitoring Report
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export values for a given client from Drive Monitoring to csv.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER OutputPath
	The path where the csv files should be stored.
	Defaults to the script root.
.PARAMETER Domain
	The domain of the client.
.PARAMETER ClientName
	The name of the client.
.OUTPUTS
	none
.NOTES
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	29.11.2023
	Purpose/Change:	Align with new api and coding standards
.EXAMPLE
	.\Export-MaintenanceRebootReportByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
.EXAMPLE
	.\Export-MaintenanceRebootReportByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client" -OutputPath "C:\Temp"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $false)]	
	[String]
	$OutputPath = "$PSScriptRoot",
	[parameter(Mandatory = $true)]
	[String]
	$Domain,
	[parameter(Mandatory = $true)]
	[String]
	$ClientName
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "MaintenanceRebootReport.csv"

$clientByNameUrl = "$ServerName/api/Client/$Domain/$ClientName"
$maintenanceRebootReportUrl = "$ServerName/api/MaintenanceReportV3/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$client = Invoke-RestMethod -Method Get -Uri $clientByNameUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

if ($null -eq $client) {
	Write-Warning "No client found for $($Domain)\$($ClientName)"
	Exit 1
}

$report = Invoke-RestMethod -Method Get -Uri $maintenanceRebootReportUrl.Replace("{CLIENTID}", "$($client.Id)") -UseDefaultCredentials -ErrorAction Stop
if ($null -eq $report) {
	Write-Warning "No drive monitoring report found for $($Domain)\$($ClientName)"
	Exit 1
}

$output = New-Object Collections.Generic.List[System.Object]

$obj = New-Object System.Object
$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
$obj | Add-Member -type NoteProperty -name ReportDate -value $report.CreatedOn
$obj | Add-Member -type NoteProperty -name LastRebootEvent -value $report.LastRebootEvent
$obj | Add-Member -type NoteProperty -name ClientLocked -value $report.ClientLocked
$obj | Add-Member -type NoteProperty -name CurrentRevokeCount -value $report.CurrentRevokeCount

$output.Add($obj)

$output | Export-Csv  -Path $filePath -NoClobber -NoTypeInformation -Encoding Default