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
	Purpose/Change:	Initial version — reproduce the WSUS ReportDetails view via API.
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

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "WsusReportDetails_$($Domain)_$($ClientName).csv"

$clientByNameUrl = "$ServerName/api/Client/$Domain/$ClientName"
$siReportUrl = "$ServerName/api/ServiceInfrastructureV3/{CLIENTID}"
$wsusComputerTargetByNetbiosUrl = "$ServerName/api/WsusComputerTargetV2/$([System.Guid]::Empty)?netBiosName={NETBIOSNAME}"
$wsusUpdateSummariesPerComputerTargetUrl = "$ServerName/api/WsusUpdateSummariesPerComputerV2/{CLIENTNAME}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$client = Invoke-RestMethod -Method Get -Uri $clientByNameUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
if ($null -eq $client) {
	Write-Warning "No client found for $($Domain)\$($ClientName)"
	Exit 1
}

$siReport = Invoke-RestMethod -Method Get -Uri $siReportUrl.Replace("{CLIENTID}", "$($client.Id)") -Headers $headers -UseDefaultCredentials -ErrorAction Stop
if ($null -eq $siReport) {
	Write-Warning "No Service Infrastructure report found for $($Domain)\$($ClientName)"
	Exit 1
}

$computerTarget = Invoke-RestMethod -Method Get -Uri $wsusComputerTargetByNetbiosUrl.Replace("{NETBIOSNAME}", "$($Domain)\$($ClientName)") -Headers $headers -UseDefaultCredentials -ErrorAction Stop
if ($null -eq $computerTarget) {
	Write-Warning "No WSUS computer target found for $($Domain)\$($ClientName)"
	Exit 1
}

$updateSummary = Invoke-RestMethod -Method Get -Uri $wsusUpdateSummariesPerComputerTargetUrl.Replace("{CLIENTNAME}", "$($computerTarget.FullDomainName)") -Headers $headers -UseDefaultCredentials -ErrorAction Stop
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
