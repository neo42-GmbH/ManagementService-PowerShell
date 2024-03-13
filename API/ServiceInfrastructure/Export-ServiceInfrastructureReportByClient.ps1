#requires -version 4
<#
.SYNOPSIS
	Export a single Service Infrastructure Report
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export values for a given client from Service Infrastructure to csv.
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
	Creation Date:	29.11.2023
	Purpose/Change:	Align with new api and coding standards
.EXAMPLE
	.\Export-ServiceInfrastructureReportByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
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
$filePath = Join-Path -Path $OutputPath -ChildPath "ServiceInfrastructureReport.csv"

$clientByNameUrl = "$ServerName/api/Client/$Domain/$ClientName"
$siReportUrl = "$ServerName/api/ServiceInfrastructureV3/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$client = Invoke-RestMethod -Method Get -Uri $clientByNameUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

if ($null -eq $client) {
	Write-Warning "No client found for $($Domain)\$($ClientName)"
	Exit 1
}

$report = Invoke-RestMethod -Method Get -Uri $siReportUrl.Replace("{CLIENTID}", "$($client.Id)") -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$output = New-Object Collections.Generic.List[System.Object]
if ($null -eq $report) {
	Write-Warning "No Service Infrastructure report found for $($Domain)\$($ClientName)"
	Exit 1
}

$obj = New-Object System.Object
$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
$obj | Add-Member -type NoteProperty -name Domain -value $client.Domain
$obj | Add-Member -type NoteProperty -name IsOnline -value $report.IsOnline
$obj | Add-Member -type NoteProperty -name ClientVersion -value $report.Version
$obj | Add-Member -type NoteProperty -name LastContact -value $report.LastContact
$obj | Add-Member -type NoteProperty -name LastLogonUser -value $report.LastLogonUser
$obj | Add-Member -type NoteProperty -name LastLogonTime -value $($report.LogonEvents | Sort-Object -Property Time -Descending | Select-Object -First 1).Time
$output.Add($obj)

$output | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default