#requires -version 5
<#
.SYNOPSIS
	Lists all BitLocker recovery keys from the backup table
.DESCRIPTION
	Starting with Management Service 2.1, you can allow clients to 
	purge BitLocker recovery keys. This process deletes the keys not 
	needed by local devices that are still in the Active Directory or the MMS DB.
	Before the MMS deletes these keys they are stored in the MMS DB.
	With this script you can export these stored keys.
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
	Creation Date:  30.11.2023
	Purpose/Change: Align with new api and coding standards
.EXAMPLE
	.\Load-PurgedBitLockerRecoveryKeys.ps1 -ServerName "https://server.domain:4242"
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
$filePath = Join-Path -Path $OutputPath -ChildPath "PurgedBitLockerRecoveryKeys.csv"

$clientUrl = "$ServerName/api/Client"
$blRecBackupURL = "$ServerName/api/BitlockerRecoveryKeyBackup"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$clientsRaw = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$clients = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($client in $clientsRaw) {
	$clients.Add($client.Id, $client)
}

$oldRecoveryKeys = Invoke-RestMethod -Method Get -Uri $blRecBackupURL -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$output = New-Object Collections.Generic.List[System.Object]
foreach ($oldKey in $oldRecoveryKeys) {
	$client = $clients[$($oldKey.ClientId)]
	if ($null -ne $client) {
		$clientName = $client.FullyQualifiedDomainName
	}
	else {
		$clientName = $oldKey.ClientId
	}

	$obj = New-Object System.Object
	$obj | Add-Member -type NoteProperty -name CreationDate -value $oldKey.CreationDate
	$obj | Add-Member -type NoteProperty -name Client -value $clientName
	$obj | Add-Member -type NoteProperty -name SourceStore -value $oldKey.SourceStore
	$obj | Add-Member -type NoteProperty -name RecoveryKeyId -value $oldKey.RecoveryKeyId
	$obj | Add-Member -type NoteProperty -name RecoveryKey -value $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($oldKey.Key)) )
	
	$output.Add($obj)    
}

$output | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default