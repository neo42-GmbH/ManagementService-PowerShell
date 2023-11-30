#requires -version 5
<#
.SYNOPSIS
	Get all the running services of a specific client
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
    to get all the running services of a specific client.
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
	Version:        1.0
	Author:         neo42 GmbH
	Creation Date:  30.11.2023
	Purpose/Change: Initial version
.EXAMPLE
	.\Export-DeviceInformationRunningServicesByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName,
	[Parameter(Mandatory = $false)]
	[string]
	$OutputPath = "$PSScriptRoot",
    [parameter(Mandatory = $true)]
    [String]
    $Domain,
    [parameter(Mandatory = $true)]
    [String]
    $ClientName
)

$clientUrl = "$ServerName/api/Client/$Domain/$ClientName"
$deviceInformationSvcReportUrl = "$ServerName/api/DeviceInformationV2/{CLIENTID}"

$filePath = Join-Path -Path $OutputPath -ChildPath "DeviceInformationServices.csv"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$client = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$services = Invoke-RestMethod -Method Get -Uri $deviceInformationSvcReportUrl.Replace("{CLIENTID}", $client.id) -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$services.OperatingSystem.Services | Where-Object { $_.Status -eq "Running" } | Select-Object -Property Name, DisplayName, StartType, StartUser | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default
