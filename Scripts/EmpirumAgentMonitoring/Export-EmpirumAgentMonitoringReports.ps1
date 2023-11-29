#requires -version 5
<#
.SYNOPSIS
	Exports all Empirum Agent Monitoring Reports
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export values for all known clients from Empirum Agent Monitoring Reports to csv.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER OutputPath
	The path where the csv files should be stored.
	Defaults to the script root.
.OUTPUTS
	none
.NOTES
	Version:        1.1
	Author:         neo42 GmbH
	Creation Date:  29.11.2023
	Purpose/Change: Align with new api and coding standards
.EXAMPLE
	.\Export-EmpirumAgentMonitoringReports.ps1
#>
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $false)]	
	[String]
	$OutputPath = "$PSScriptRoot"
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "EmpirumAgentMonitoringReports.csv"

$clientUrl = "$ServerName/api/client"
$empirumReportUrl = "$ServerName/api/EmpirumMonitoringReportV2"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$rawreports = Invoke-RestMethod -Method Get -Uri $empirumReportUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$reports = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($report in $rawreports) {
	if ($null -eq $report.Report) {
		continue
	}
	$reports.Add($report.Report.ClientId, $report)
}

$output = New-Object Collections.Generic.List[System.Object]
foreach ($client in $clients) {
	$report = $reports[$($client.Id)]
	if ($null -eq $report) {
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

$output | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default