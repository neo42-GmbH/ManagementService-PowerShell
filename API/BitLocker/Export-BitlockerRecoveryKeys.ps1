#Requires -Version 5
<#
.SYNOPSIS
	Export Bitlocker Recovery Keys from neo42 Management Service and Active Directory if available
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to receive Bitlocker RecoveryKeys

	Caution: the resulting csv contains recovery keys in clear text. Store it
	accordingly and delete it when it is no longer needed.
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
	./Export-BitlockerRecoveryKeys.ps1 -ServerName "https://server.domain:4242"
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

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "BitlockerRecoveryKeys.csv"

$clients = Get-MmsClient

foreach ($client in $clients) {
	$AdRecoveryKeys = Get-MmsBitLockerRecoveryKey -ClientId $client.Id -Source Ad
	$AdRecoveryKeys | Select-Object -ExcludeProperty key *, @{
		Label      = "StoredIn"
		Expression = { "AD" }
	}, @{
		Label      = "key"
		Expression = { $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.key))) }
	} | Export-Csv -NoTypeInformation -Append -Path $filePath -Encoding UTF8

	$MMSRecoveryKeys = Get-MmsBitLockerRecoveryKey -ClientId $client.Id -Source Mms
	$MMSRecoveryKeys | Select-Object -ExcludeProperty key *, @{
		Label      = "StoredIn"
		Expression = { "MMS" }
	}, @{
		Label      = "key"
		Expression = { $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.key))) }
	} | Export-Csv -NoTypeInformation -Append -Path $filePath -Encoding UTF8
}
