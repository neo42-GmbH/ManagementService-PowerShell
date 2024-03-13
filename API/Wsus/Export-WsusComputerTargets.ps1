#requires -version 5
<#
.SYNOPSIS
	Exports all WSUS Clients with update summaries
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export values for all known wsus clients to csv.
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
	Purpose/Change:	Align with new api and coding standards
.EXAMPLE
	.\Export-WsusComputerTargets.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $false)]	
	[String]
	$OutputPath = "$PSScriptRoot"
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "WsusComputerTargets.csv"

$wsusComputerTargetUrl = "$ServerName/api/WsusComputerTargetV2"
$wsusUpdateSummariesPerComputerTargetUrl = "$ServerName/api/WsusUpdateSummariesPerComputerV2"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$rawComputerTargets = Invoke-RestMethod -Method Get -Uri $wsusComputerTargetUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$updateSummaries = Invoke-RestMethod -Method Get -Uri $wsusUpdateSummariesPerComputerTargetUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$computerTargets = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($target in $rawComputerTargets) {
	$computerTargets.Add($target.Id, $target)
}

$output = New-Object Collections.Generic.List[System.Object]
foreach ($updateSummary in $updateSummaries) {
	$report = $computerTargets[$($updateSummary.ComputerTarget)]
	if ($null -eq $report) {
		continue
	}

	$obj = New-Object System.Object
	$obj | Add-Member -type NoteProperty -name FQDN -value $report.FullDomainName
	$obj | Add-Member -type NoteProperty -name ComputerRole -value $report.ComputerRole
	$obj | Add-Member -type NoteProperty -name LastReportedStatusTime -value $report.LastReportedStatusTime
	$obj | Add-Member -type NoteProperty -name LastSyncTime -value $report.LastSyncTime
	$obj | Add-Member -type NoteProperty -name Failed -value $updateSummary.FailedCount
	$obj | Add-Member -type NoteProperty -name Installed -value $updateSummary.InstalledCount
	$obj | Add-Member -type NoteProperty -name InstalledPendingReboot -value $updateSummary.InstalledPendingRebootCount

	$output.Add($obj)
}

$output | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default