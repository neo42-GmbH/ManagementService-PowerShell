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
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	30.11.2023
	Purpose/Change:	Align with new api and coding standards
.EXAMPLE
	./Export-BitlockerReports.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName,
	[Parameter(Mandatory = $false)]
	[string]
	$OutputPath = "$PSScriptRoot"
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "BitlockerReports.csv"

# prepare request headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

# Get Clientlist from MMS Server
$clientUrl = "$ServerName/api/Client"
$bitlockerReportUrl = "$ServerName/api/BitlockerReportV4"

$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

#  Append this URL with /[ClientID] to get only the specified report
$BitlockerReports = Invoke-RestMethod -Method Get -Uri "$bitlockerReportUrl" -Headers $headers -UseDefaultCredentials -ErrorAction Stop
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