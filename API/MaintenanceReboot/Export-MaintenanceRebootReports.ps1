#requires -version 5
<#
.SYNOPSIS
	Exports all Drive Monitoring Reports
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export values for all known clients from Drive Monitoring Reports to csv.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER OutputPath
	The path where the csv files should be stored.
	Defaults to the script root.
.OUTPUTS
	none
.NOTES
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	29.11.2023
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Export-MaintenanceRebootReports.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $true)]
	[System.IO.DirectoryInfo]
	$OutputPath
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "MaintenanceRebootReports.csv"

$clients = Get-MmsClient
$rawreports = Get-MmsMaintenanceRebootReport

$reports = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($report in $rawreports) {
	$reports.Add($report.ClientId, $report)
}

$output = New-Object Collections.Generic.List[System.Object]
foreach ($client in $clients) {
	$report = $reports[$($client.Id)]
	if ($null -eq $report) {
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

$output | Export-Csv  -Path $filePath -NoClobber -NoTypeInformation -Encoding Default