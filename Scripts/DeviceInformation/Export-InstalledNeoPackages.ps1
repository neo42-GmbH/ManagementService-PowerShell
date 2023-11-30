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
	Purpose/Change: Initial version
.EXAMPLE
	.\Export-InstalledNeoPackages.ps1 -ServerName "https://server.domain:4242"
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

$filePath = Join-Path -Path $OutputPath -ChildPath "InstalledNeoPackages.csv"

$clientUrl = "$ServerName/api/Client/$Domain/$ClientName"
$deviceInformationSoftwareUrl = "$ServerName/api/DeviceInformationV2/?type=sw"


$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$clientsRaw = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$clientsDict = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($client in $clientsRaw) {
    $clientsDict.Add($client.Id, ($client | Select-Object -Property NetBiosName, Id))
}

$deviceInformationSoftware = Invoke-RestMethod -Method Get -Uri $deviceInformationSoftwareUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

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