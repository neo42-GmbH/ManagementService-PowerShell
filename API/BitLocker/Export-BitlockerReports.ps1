#Requires -Version 5
<#
.SYNOPSIS
	Export neo42 Management Service BitlockerReports
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export values from Bitlocker Reports to csv.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER OutputPath
	The path where the csv files should be stored.
	Defaults to the script root.
.OUTPUTS
	none
.NOTES
	Version:		2.0
	Author:			neo42 GmbH
	Creation Date:	30.11.2023
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	./Export-BitlockerReports.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
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

# Opens the session that every following call uses. Add -Credential to run as
# another Windows account.
Connect-MmsApi -ServerName $ServerName

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "BitlockerReports.csv"

$clients = Get-MmsClient

# Pass -ClientId to get only the report of a single client
$BitlockerReports = Get-MmsBitLockerReport
$BitlockerReportCollection = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($BitlockerReport in $BitlockerReports) {
	$BitlockerReportCollection.Add($BitlockerReport.ClientID, $BitlockerReport)
}

$Compliancestates = New-Object "System.Collections.Generic.Dictionary[[Int],[String]]"
$Compliancestates[0] = "No Report"
$Compliancestates[1] = "Not Compliant"
$Compliancestates[2] = "Compliant"

$out = $clients | Select-Object Id, name, @{
	Label      = "ComplianceState"
	Expression = { $Compliancestates[$BitlockerReportCollection[$_.id].ComplianceState] }
}, @{
	Label      = "CurrentConfiguration"
	Expression = { $BitlockerReportCollection[$_.id].CurrentConfigurationInfo.name }
}, @{
	Label      = "TargetConfiguration"
	Expression = { $BitlockerReportCollection[$_.id].TargetConfigurationInfo.name }
}, @{
	Label      = "EncryptionPercentage"
	Expression = { $BitlockerReportCollection[$_.id].EncryptionPercentage }
}

$out | Export-Csv -Encoding UTF8 -Path $filePath -NoTypeInformation
