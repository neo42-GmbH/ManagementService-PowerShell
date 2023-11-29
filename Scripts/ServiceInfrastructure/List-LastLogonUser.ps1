#requires -version 5
<#
.SYNOPSIS
	List all known Clients, their Last Contact and Last known Logon User
.DESCRIPTION
	Exports all known Clients and their last Logon User to a csv file.
	The data is based on the reports of the Service Infrastructure plug-in.
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
	.\List-LastLogonUser.ps1 -ServerName "https://server.domain:4242"
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
$filePath = Join-Path -Path $OutputPath -ChildPath "LastLogonUser.csv"

$clientUrl = "$ServerName/api/client"
$siURL = "$ServerName/api/ServiceInfrastructureV3"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$rawreports = Invoke-RestMethod -Method Get -Uri $SiUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$reports = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($report in $rawreports.data) {
	$reports.Add($report.ClientId, $report)
}

$output = New-Object Collections.Generic.List[System.Object]
foreach ($client in $clients) {
	$report = $reports[$($client.Id)]
	if ($null -eq $report) {
		continue
	}
	$obj = New-Object System.Object
	$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
	$obj | Add-Member -type NoteProperty -name Domain -value $client.Domain
	$obj | Add-Member -type NoteProperty -name IsOnline -value $report.IsOnline
	$obj | Add-Member -type NoteProperty -name LastLogonUser -value $report.LastLogonUser
	$obj | Add-Member -type NoteProperty -name LastContact -value $report.LastContact
	$output.Add($obj)
}

$output | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default