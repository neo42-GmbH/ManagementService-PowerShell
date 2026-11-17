#requires -version 5
<#
.SYNOPSIS
	Returns MMS Clients and the last Logon of a given User.
.DESCRIPTION
	Searches for the last logins in reports sent to neo42 Management Service by domain and username.
	Depending on the size of your environment and the amount of data to be searched through this might
	take some time. The output is saved to csv in addition to console output.  
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER OutputPath
	The path where the csv files should be stored.
	Defaults to the script root.
.PARAMETER Domain
	The domain of the user.
.PARAMETER Username
	The username to search for.
.OUTPUTS
	none.
.NOTES
	Version:				1.1
	Author:					neo42 GmbH
	Creation Date:			30.11.2021
	Purpose/Change:			Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
	Required MMS Server:	2.8.5.0
.EXAMPLE
	.\Find-MmsClientByLastLogonUser.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -UserName "user"
#>
[CmdletBinding()]
param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $true)]
	[System.IO.DirectoryInfo]
	$OutputPath,
	[Parameter(Mandatory = $true)]
	[String]
	$Domain,
	[Parameter(Mandatory = $true)]
	[String]
	$UserName
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
$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "$($Domain)_$($UserName).csv"

$clients = Get-MmsClient

foreach ($client in $clients) {
	$report = Get-MmsServiceInfrastructureReport -ClientId $client.Id
	if ($null -eq $report) {
		continue
	}
	$loggedOnTo = $null
	$loggedOnTo = $report.LogonEvents | Sort-Object -Descending -Property Time | Where-Object { $_.Domain -eq $Domain -and $_.User -eq $UserName } | Select-Object -First 1
	if ($null -eq $loggedOnTo) {
		continue
	}
	$obj = New-Object System.Object
	$obj | Add-Member -type NoteProperty -name Id -value $client.Id
	$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
	$obj | Add-Member -type NoteProperty -name Domain -value $client.Domain
	$obj | Add-Member -type NoteProperty -name IsOnline -value $report.IsOnline
	$obj | Add-Member -type NoteProperty -name LastLogonUser -value $report.LastLogonUser
	$obj | Add-Member -type NoteProperty -name LastContact -value $report.LastContact
	$obj | Add-Member -type NoteProperty -name TargetLoggedOnTo -value $loggedOnTo.Time
	$obj | Export-Csv $filePath -NoTypeInformation -Append 
	$obj
}