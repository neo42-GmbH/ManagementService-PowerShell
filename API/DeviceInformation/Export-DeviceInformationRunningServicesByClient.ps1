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
	Purpose/Change: Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Export-DeviceInformationRunningServicesByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
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

$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "DeviceInformationServices.csv"

$client = Get-MmsClient -Domain $Domain -Name $ClientName
$services = Get-MmsDeviceInformation -ClientId $client.Id

$services.OperatingSystem.Services | Where-Object { $_.Status -eq "Running" } | Select-Object -Property Name, DisplayName, StartType, StartUser | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default
