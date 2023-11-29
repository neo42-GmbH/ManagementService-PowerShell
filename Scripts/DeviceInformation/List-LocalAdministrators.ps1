#requires -version 5
<#
.SYNOPSIS
	Lists all members of local administrator groups
.DESCRIPTION
	Exports all members of the local administrator groups to a csv file.
	The data is based on the reports of the Device Information plug-in.
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
	Creation Date:	29.11.2023
	Purpose/Change: Align with new api and coding standards

.EXAMPLE
	.\List-LocalAdministrators.ps1
#>

Param (
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName,
	[Parameter(Mandatory = $false)]
	[string]
	$OutputPath = "$PSScriptRoot"
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "LocalAdministrators.csv"

# Filter with possible names of local admin groups
filter groupFilter { if ($_.Name -EQ "Administratoren" -OR $_.Name -EQ "Administrators") { $_ } }

$clientUrl = "$ServerName/api/client"
$osUrl = "$ServerName/api/partialdiinformation/os"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$rawreports = Invoke-RestMethod -Method Get -Uri $osUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$reports = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($report in $rawreports) {
	$reports.Add($report.Id, $report)
}

$output = New-Object Collections.Generic.List[System.Object]
foreach ($client in $clients) {
	$report = $reports[$($client.Id)]
	if ($null -eq $report) {
		continue
	}
	$member = $report.OperatingSystem.Groups | groupFilter
	foreach ($user in $member.User) {
		$obj = New-Object System.Object
		$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
		$obj | Add-Member -type NoteProperty -name Name -value $user.Name
		$obj | Add-Member -type NoteProperty -name Fullname -value $user.FullName
		$obj | Add-Member -type NoteProperty -name Description -value $user.Description
		$obj | Add-Member -type NoteProperty -name AccountDisabled -value $user.AccountDisabled
		$obj | Add-Member -type NoteProperty -name IsAccountLocked -value $user.IsAccountLocked
		$obj | Add-Member -type NoteProperty -name PasswordExpired -value $user.PasswordExpired
		$obj | Add-Member -type NoteProperty -name BadPasswordAttempts -value $user.BadPasswordAttempts
		$output.Add($obj)
	}
	foreach ($group in $member.Groups) {
		$obj = New-Object System.Object
		$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
		$obj | Add-Member -type NoteProperty -name Name -value $group
		$obj | Add-Member -type NoteProperty -name Fullname -value ''
		$obj | Add-Member -type NoteProperty -name Description -value ''
		$obj | Add-Member -type NoteProperty -name AccountDisabled -value ''
		$obj | Add-Member -type NoteProperty -name IsAccountLocked -value ''
		$obj | Add-Member -type NoteProperty -name PasswordExpired -value ''
		$obj | Add-Member -type NoteProperty -name BadPasswordAttempts -value ''
		$output.Add($obj)
	}
}

$output | Export-Csv  -Path $filePath -NoClobber -NoTypeInformation -Encoding Default