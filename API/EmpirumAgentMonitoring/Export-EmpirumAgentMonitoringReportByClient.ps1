#requires -version 5
<#
.SYNOPSIS
	Export a single Empirum Agent Monitoring Report
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export values for a given client from Empirum Agent Monitoring to csv.
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
	.\Export-EmpirumAgentMonitoringReportByClient.ps1 -ServerName "https://server.domain:4242" -Domain corp -ClientName client
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $true)]
	[System.IO.DirectoryInfo]
	$OutputPath,
	[parameter(Mandatory = $true)]
	[String]
	$Domain,
	[parameter(Mandatory = $true)]
	[String]
	$ClientName
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
$filename = Join-Path -Path $OutputPath.FullName -ChildPath "EmpirumAgentMonitoringReport.csv"

$client = Get-MmsClient -Domain $Domain -Name $ClientName

if ($null -eq $client) {
	Write-Warning "No client found for $Domain\$ClientName"
	Exit 1
}

$report = Get-MmsEmpirumMonitoringReport -ClientId $client.Id
$output = New-Object Collections.Generic.List[System.Object]
if (($null -eq $report) -or ($null -eq $report.Report)) {
	Write-Warning "No empirum report found for $($Domain)\$($ClientName)"
	Exit 1
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

$output | Export-Csv -Path $filename -NoClobber -NoTypeInformation -Encoding Default