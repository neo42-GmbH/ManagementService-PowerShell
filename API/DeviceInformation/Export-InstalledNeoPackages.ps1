#requires -version 5
<#
.SYNOPSIS
	Get all packages installed from the neo42 Package Depot
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
    to retrieve all packages installed from the neo42 Package Depot.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER OutputPath
	The path where the csv files should be stored.
	Defaults to the script root.
.OUTPUTS
	none
.NOTES
	Version:        1.0
	Author:         neo42 GmbH
	Creation Date:  30.11.2023
	Purpose/Change: Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Export-InstalledNeoPackages.ps1 -ServerName "https://server.domain:4242"
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

Connect-MmsApi -ServerName $ServerName

$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "InstalledNeoPackages.csv"

$clientsRaw = Get-MmsClient
$clientsDict = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($client in $clientsRaw) {
    $clientsDict.Add($client.Id, ($client | Select-Object -Property NetBiosName, Id))
}

$deviceInformationSoftware = Get-MmsDeviceInformation -Type 'sw'

$packages = @()
$deviceInformationSoftware | ForEach-Object {
    $client = $clientsDict[$_.Id]
    if ($_.PSObject.Properties.Name -notcontains "Software") {
        return
    }
    $filteredPackages = $_.Software | Where-Object { $true -eq $_.Key.startsWith("neoPackage") }
    $packages += ($filteredPackages | Select-Object -Property DisplayName,  @{Name = 'Client'; Expression = { $clientsDict[$client.Id].NetBiosName } }, InstallDate, Version)
}

$packages | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default