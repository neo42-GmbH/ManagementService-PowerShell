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
    Purpose/Change: Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
    .\Export-WsusComputerTargetByClient.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client"
#>
[CmdletBinding()]
Param (
    [parameter(Mandatory = $true)]
    [String]
    $ServerName,
    [parameter(Mandatory = $true)]
	[System.IO.DirectoryInfo]
	$OutputPath,
    [parameter(Mandatory = $true)]
    [String]
    $Domain,
    [parameter(Mandatory = $true)]
    [String]
    $ClientName
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
$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "WsusComputerTargetReport.csv"

$computerTarget = Get-MmsWsusComputerTarget -NetBiosName "$($Domain)\$($ClientName)"

# An unknown name does not answer with an error or with null: the route returns
# an empty computer target whose Id is the empty guid. That is the value to test.
if ($null -eq $computerTarget -or $computerTarget.Id -eq [System.Guid]::Empty) {
	Write-Warning "No WSUS computer target found for $($Domain)\$($ClientName)"
	Exit 1
}

# The WSUS update summary is addressed by the FullDomainName of the computer
# target, not by the MMS client id.
$updateSummary = Get-MmsWsusUpdateSummary -ComputerTarget $computerTarget.FullDomainName

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