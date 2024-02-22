#requires -version 5
<#
.SYNOPSIS
    Exports target WSUS Client with update summary
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for a target wsus clients to csv.
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
    Purpose/Change: Align with new api and coding standards
.EXAMPLE
    .\Export-WsusComputerTargetByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
#>
[CmdletBinding()]
Param (
    [parameter(Mandatory = $true)]
    [String]
    $ServerName,
    [parameter(Mandatory = $false)]	
    [String]
    $OutputPath = "$PSScriptRoot",
    [parameter(Mandatory = $true)]
    [String]
    $Domain,
    [parameter(Mandatory = $true)]
    [String]
    $ClientName
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "WsusComputerTargetReport.csv"

$wsusComputerTargetByNetbiosUrl = "$ServerName/api/WsusComputerTargetV2/$([System.Guid]::Empty)?netBiosName={NETBIOSNAME}"
$wsusUpdateSummariesPerComputerTargetUrl = "$ServerName/api/WsusUpdateSummariesPerComputerV2/{CLIENTNAME}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$computerTarget = Invoke-RestMethod -Method Get -Uri $wsusComputerTargetByNetbiosUrl.Replace("{NETBIOSNAME}", "$($Domain)\$($ClientName)") -Headers $headers -UseDefaultCredentials

$updateSummary = Invoke-RestMethod -Method Get -Uri $wsusUpdateSummariesPerComputerTargetUrl.Replace("{CLIENTNAME}", "$($computerTarget.FullDomainName)") -Headers $headers -UseDefaultCredentials

$output = New-Object Collections.Generic.List[System.Object]
$obj = New-Object System.Object
$obj | Add-Member -type NoteProperty -name FQDN -value $computerTarget.FullDomainName
$obj | Add-Member -type NoteProperty -name ComputerRole -value $computerTarget.ComputerRole
$obj | Add-Member -type NoteProperty -name LastReportedStatusTime -value $computerTarget.LastReportedStatusTime
$obj | Add-Member -type NoteProperty -name LastSyncTime -value $computerTarget.LastSyncTime
$obj | Add-Member -type NoteProperty -name Failed -value $updateSummary.FailedCount
$obj | Add-Member -type NoteProperty -name Installed -value $updateSummary.InstalledCount
$obj | Add-Member -type NoteProperty -name InstalledPendingReboot -value $updateSummary.InstalledPendingRebootCount

$output.Add($obj)

$output | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default