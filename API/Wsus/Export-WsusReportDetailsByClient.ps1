#requires -version 5
<#
.SYNOPSIS
	Aggregates the data shown on the "ReportDetails" page (WSUS view) for a single client via the API.
.DESCRIPTION
	The "/ReportDetails/{initialPluginId}/{clientId}" URL of the neo42 Management Service Blazor UI is an
	aggregation page that combines several plug-in reports in tabs. There is no single REST endpoint
	behind it. This script reproduces the WSUS view of that page (DETAILS + UPDATE STATUS tabs) for a
	given client by combining the existing Client, ServiceInfrastructure, WsusComputerTarget and
	WsusUpdateSummariesPerComputer endpoints.

	The result is exported to a CSV file and also returned to the pipeline.
.PARAMETER ServerName
	The servername of the neo42 Management Service (e.g. "https://server.domain:4242").
.PARAMETER OutputPath
	The path where the csv file should be stored.
	Defaults to the script root.
.PARAMETER Domain
	The domain of the client.
.PARAMETER ClientName
	The name of the client.
.OUTPUTS
	System.Management.Automation.PSCustomObject — the aggregated ReportDetails record.
.NOTES
	Version:		1.0
	Author:			neo42 GmbH
	Creation Date:	05.05.2026
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Export-WsusReportDetailsByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
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
$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "WsusReportDetails_$($Domain)_$($ClientName).csv"

$client = Get-MmsClient -Domain $Domain -Name $ClientName
if ($null -eq $client) {
	Write-Warning "No client found for $($Domain)\$($ClientName)"
	Exit 1
}

$siReport = Get-MmsServiceInfrastructureReport -ClientId $client.Id
if ($null -eq $siReport) {
	Write-Warning "No Service Infrastructure report found for $($Domain)\$($ClientName)"
	Exit 1
}

$computerTarget = Get-MmsWsusComputerTarget -NetBiosName "$($Domain)\$($ClientName)"

# An unknown name does not answer with an error or with null: the route returns
# an empty computer target whose Id is the empty guid. That is the value to test.
if ($null -eq $computerTarget -or $computerTarget.Id -eq [System.Guid]::Empty) {
	Write-Warning "No WSUS computer target found for $($Domain)\$($ClientName)"
	Exit 1
}

# The WSUS update summary is addressed by the FullDomainName of the computer
# target, not by the MMS client id.
$updateSummary = Get-MmsWsusUpdateSummary -ComputerTarget $computerTarget.FullDomainName
if ($null -eq $updateSummary) {
	Write-Warning "No WSUS update summary found for $($computerTarget.FullDomainName)"
	Exit 1
}

$lastLogon = $siReport.LogonEvents | Sort-Object -Property Time -Descending | Select-Object -First 1

$obj = New-Object System.Object
$obj | Add-Member -type NoteProperty -name ClientId -value $client.Id
$obj | Add-Member -type NoteProperty -name Name -value $client.NetBiosName
$obj | Add-Member -type NoteProperty -name Domain -value $client.Domain
$obj | Add-Member -type NoteProperty -name FullDomainName -value $computerTarget.FullDomainName
$obj | Add-Member -type NoteProperty -name IsOnline -value $siReport.IsOnline
$obj | Add-Member -type NoteProperty -name ClientVersion -value $siReport.Version
$obj | Add-Member -type NoteProperty -name LastContact -value $siReport.LastContact
$obj | Add-Member -type NoteProperty -name LastReportedStatusTime -value $computerTarget.LastReportedStatusTime
$obj | Add-Member -type NoteProperty -name LastSyncTime -value $computerTarget.LastSyncTime
$obj | Add-Member -type NoteProperty -name ComputerRole -value $computerTarget.ComputerRole
$obj | Add-Member -type NoteProperty -name LastLogonUser -value $siReport.LastLogonUser
$obj | Add-Member -type NoteProperty -name LastLogonTime -value $lastLogon.Time
$obj | Add-Member -type NoteProperty -name WsusFailed -value $updateSummary.FailedCount
$obj | Add-Member -type NoteProperty -name WsusInstalled -value $updateSummary.InstalledCount
$obj | Add-Member -type NoteProperty -name WsusInstalledPendingReboot -value $updateSummary.InstalledPendingRebootCount
$obj | Add-Member -type NoteProperty -name WsusNeededCount -value $updateSummary.NeededCount
$obj | Add-Member -type NoteProperty -name WsusNeededApprovedCount -value $updateSummary.NeededApprovedCount

$output = New-Object Collections.Generic.List[System.Object]
$output.Add($obj)

$output | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default

Write-Output $obj
