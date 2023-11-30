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
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	30.11.2023
	Purpose/Change:	Align with new api and coding standards
.EXAMPLE
	.\Export-BitLockerReportByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
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
$filePath = Join-Path -Path $OutputPath -ChildPath "BitLockerReport.csv"

$clientByNameUrl = "$ServerName/api/Client/$Domain/$ClientName"
$bitlockerReportUrl = "$ServerName/api/BitlockerReportV4/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$client = Invoke-RestMethod -Method Get -Uri $clientByNameUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

if ($null -eq $client) {
	Write-Warning "No client found for $($Domain)\$($ClientName)"
	Exit 1
}

$report = Invoke-RestMethod -Method Get -Uri $bitlockerReportUrl.Replace("{CLIENTID}", "$($client.Id)") -UseDefaultCredentials -ErrorAction Stop
if ($null -eq $report) {
	Write-Warning "No drive monitoring report found for $($Domain)\$($ClientName)"
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