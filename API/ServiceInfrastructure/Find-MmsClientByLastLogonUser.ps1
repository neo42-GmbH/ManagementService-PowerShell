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
	Purpose/Change:			Align with new api and coding standards
	Required MMS Server:	2.8.5.0
.EXAMPLE
	.\Find-MmsClientByLastLogonUser.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -UserName "user"
#>
[CmdletBinding()]
param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $false)]	
	[String]
	$OutputPath = "$PSScriptRoot",
	[Parameter(Mandatory = $true)]
	[String]
	$Domain,
	[Parameter(Mandatory = $true)]
	[String]
	$UserName
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "$($Domain)_$($UserName).csv"

$clientUrl = "$ServerName/api/Client"
$siUrl = "$ServerName/api/ServiceInfrastructureV3/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

foreach ($client in $clients) {
	$report = Invoke-RestMethod -Method Get -Uri $siUrl.Replace("{CLIENTID}", $($client.Id)) -Headers $headers -UseDefaultCredentials
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