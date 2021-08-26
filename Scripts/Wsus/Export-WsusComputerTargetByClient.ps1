#requires -version 4
<#
.SYNOPSIS
    Exports target WSUS Client with update summary
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for a target wsus clients to csv.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  13.08.2021
    Purpose/Change: Initial version
  
.EXAMPLE
    .\Export-WsusComputerTargetByClient.ps1 -Domain corp -ClientName client
#>
Param
  (
    [parameter(Mandatory=$true)]
    [String]
    $Domain,
    [parameter(Mandatory=$true)]
    [String]
    $ClientName
  )


# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\WsusComputerTarget.csv"

$wsusComputerTargetByNetbiosUrl = "$servername/api/WsusComputerTarget/00000000-0000-0000-0000-000000000000?netBiosName={NETBIOSNAME}"
$wsusUpdateSummariesPerComputerTargetUrl = "$servername/api/WsusUpdateSummariesPerComputer/{CLIENTNAME}"

$headers=New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$headersv2=New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headersv2.Add("X-Neo42-Auth", "Admin")
$headersv2.Add("X-Neo42-ControllerVersion", "2")

$computerTarget = Invoke-RestMethod -Method Get -Uri $wsusComputerTargetByNetbiosUrl.Replace("{NETBIOSNAME}","$($Domain)\$($ClientName)") -Headers $headersv2 -UseDefaultCredentials

$updateSummary = Invoke-RestMethod -Method Get -Uri $wsusUpdateSummariesPerComputerTargetUrl.Replace("{CLIENTNAME}","$($computerTarget.FullDomainName)") -Headers $headers -UseDefaultCredentials

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

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default