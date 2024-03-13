#Requires -Version 5
<#
.SYNOPSIS
	Export Bitlocker Recovery Keys from neo42 Management Service and Active Directory if available
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to receive Bitlocker RecoveryKeys
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
	./Export-BitlockerRecoveryKeys.ps1 -ServerName "https://server.domain:4242"
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
$filePath = Join-Path -Path $OutputPath -ChildPath "BitlockerRecoveryKeys.csv"

#prepare request headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

# Get Clientlist from MMS Server
$clientUrl = "$ServerName/api/client"
$adRecoveryKeyUrl = "$ServerName/api/BitlockerAdRecoveryKey/{CLIENTID}"
$mmsRecoveryKeyUrl = "$ServerName/api/BitlockerInBuiltRecoveryKey/{CLIENTID}"

$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

foreach ($client in $clients) {
	$AdRecoveryKeys = Invoke-RestMethod -Method Get -Uri $adRecoveryKeyUrl.Replace('{CLIENTID}', $client.id) -Headers $headers -UseDefaultCredentials
	$AdRecoveryKeys | Select-Object -ExcludeProperty key *, @{
		Label      = "StoredIn"
		Expression = { "AD" }
	}, @{
		Label      = "key"
		Expression = { $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.key))) }
	} | Export-Csv -NoTypeInformation -Append -Path $filePath -Encoding UTF8
	$MMSRecoveryKeys = Invoke-RestMethod -Method Get -Uri $mmsRecoveryKeyUrl.Replace('{CLIENTID}', $client.id) -Headers $headers -UseDefaultCredentials
	$MMSRecoveryKeys | Select-Object -ExcludeProperty key *, @{
		Label      = "StoredIn"
		Expression = { "MMS" }
	}, @{
		Label      = "key"
		Expression = { $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.key))) }
	} | Export-Csv -NoTypeInformation -Append -Path $filePath -Encoding UTF8
}
