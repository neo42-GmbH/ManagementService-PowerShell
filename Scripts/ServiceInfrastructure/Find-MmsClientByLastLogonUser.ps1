#requires -version 4
<#
.SYNOPSIS
    Returns MMS Clients and the last Logon of a given User.
.DESCRIPTION
    Searches for the last logins in reports sent to neo42 Management Service by domain and username.
    Depending on the size of your environment and the amount of data to be searched through this might
    take some time. The output is saved to csv in addition to console output.  
.INPUTS
    Domain, Username
.OUTPUTS
    MMS Clientobjects, File: <domain>_<Username>.csv
.NOTES
    Version:             1.0
    Author:              neo42 GmbH
    Creation Date:       30.11.2021
    Purpose/Change:      Initial version
    Required MMS Server: 2.8.5.0
.COMPONENT
    neo42 Management Service
.EXAMPLE
    .\Find-MmsClientByLastLogonUser.ps1 -Domain "neo" -Username "admin"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [String]
    $Domain,
    [Parameter(Mandatory=$true)]
    [String]
    $UserName
)

# Fill with current servername
$servername='https://server.domain:443'

# Filename with the collected data
$filename = "$($PSScriptRoot)\$($Domain)_$($username).csv"

$clientUrl = "$servername/api/client"
$siUrl = "$servername/api/ServiceInfrastructureV2/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")
$clients = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials

foreach($client in $clients)
{
    $report = Invoke-RestMethod -Method Get -Uri $siUrl.Replace("{CLIENTID}",$($client.Id)) -Headers $headers -UseDefaultCredentials
    if($null -eq $report)
    {
        continue
    }
    $loggedOnTo = $null
    $loggedOnTo = $report.LogonEvents | Sort-Object -Descending -Property Time | Where-Object { $_.Domain -eq $Domain -and $_.User -eq $UserName } | Select-Object -First 1
    if($null -eq $loggedOnTo)
    {
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
    $obj | Export-Csv $filename -NoTypeInformation -Append 
    $obj
}