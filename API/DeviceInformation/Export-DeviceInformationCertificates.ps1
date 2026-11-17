#requires -version 5
<#
.SYNOPSIS
	Exports all certificate information from the Device Information plug-in
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export certificate values for all known clients from the Device Information plug-in to csv.
	Since clients often have a large amount of certificates the process can be very time and cpu
	consuming and creates large output files!
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
	Purpose/Change: Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Export-DeviceInformationCertificates.ps1 -ServerName "https://server.domain:4242"
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

$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "DeviceInformationCertificates_{COUNTER}.csv"

$clientsRaw = Get-MmsClient
$clientsDict = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($client in $clientsRaw) {
	$clientsDict.Add($client.Id, $client.NetBiosName)
}

$offset = 0
$limit = 500

$fileNameCounter = 0
$loopCounter = 0

do {
	$loopCounter++
	if ($loopCounter -gt 4) {
		$loopCounter = 0
		$fileNameCounter++
	}
	$output = New-Object Collections.Generic.List[System.Object]
	$page = Get-MmsDeviceInformation -Type 'cert' -Offset $offset -Limit $limit
	$page | ForEach-Object {
		if ($clientsDict.ContainsKey($_.Id)) {
			foreach ($store in $_.OperatingSystem.CertificateStores) {
				foreach ($certificate in $store.Certificates) {
					$obj = New-Object System.Object
					$obj | Add-Member -type NoteProperty -name Client -value $clientsDict[$_.Id]
					$obj | Add-Member -type NoteProperty -name Store -value $store.FriendlyName
					$obj | Add-Member -type NoteProperty -name CertName -value $certificate.Name
					$obj | Add-Member -type NoteProperty -name Issuer -value $certificate.Issuer
					$obj | Add-Member -type NoteProperty -name Subject -value $certificate.Subject
					$obj | Add-Member -type NoteProperty -name NotBefore -value $certificate.NotBefore
					$obj | Add-Member -type NoteProperty -name NotAfter -value $certificate.NotAfter
					$obj | Add-Member -type NoteProperty -name Serial -value $certificate.Serial
					$obj | Add-Member -type NoteProperty -name Thumbprint -value $certificate.Thumbprint
					$obj | Add-Member -type NoteProperty -name HasPrivateKey -value $certificate.PrivateKey
					$output.Add($obj)
				}
			}    
		}
	}
	$output | Export-Csv  -Path $($filePath).Replace("{COUNTER}", $fileNameCounter) -NoClobber -NoTypeInformation -Encoding Default -Append
	$offset += $limit
	Write-Output "Clients written to csv files: $offset"
} while ($page.Count -eq $limit)