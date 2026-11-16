#requires -version 5
<#
.SYNOPSIS
	Export a single BitLocker Report
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export values for a given client from BitLocker to csv.
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
	Version:		2.0
	Author:			neo42 GmbH
	Creation Date:	30.11.2023
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Export-BitLockerReportByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
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
$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "BitLockerReport.csv"

$client = Get-MmsClient -Domain $Domain -Name $ClientName

if ($null -eq $client) {
	Write-Warning "No client found for $($Domain)\$($ClientName)"
	Exit 1
}

# Get-MmsBitLockerReport unwraps the { Data, Errors, Meta } envelope of the API,
# so the report properties are available directly.
$report = Get-MmsBitLockerReport -ClientId $client.Id
if ($null -eq $report) {
	Write-Warning "No BitLocker report found for $($Domain)\$($ClientName)"
	Exit 1
}

$Compliancestates = New-Object "System.Collections.Generic.Dictionary[[Int],[String]]"
$Compliancestates[0] = "No Report"
$Compliancestates[1] = "Not Compliant"
$Compliancestates[2] = "Compliant"

$obj = New-Object System.Object
$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
$obj | Add-Member -type NoteProperty -name ReportDate -value $report.CreationDate
$obj | Add-Member -type NoteProperty -name State -value $Compliancestates[$report.ComplianceState]
$obj | Add-Member -type NoteProperty -name CurrentEncryptionTries -value $report.CurrentEncryptionTriesCount
$obj | Add-Member -type NoteProperty -name MaxEncryptionTries -value $report.MaxEncryptionTriesCount

$output = New-Object Collections.Generic.List[System.Object]
$output.Add($obj)

$output | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default
