#requires -version 4
<#
.SYNOPSIS
    Exports all WSUS Clients with update summaries
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for all known wsus clients to csv.
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
    .\Export-WsusComputerTargets.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\WsusComputerTargets.csv"

$wsusComputerTargetUrl = "$servername/api/WsusComputerTarget"
$wsusUpdateSummariesPerComputerTargetUrl = "$servername/api/WsusUpdateSummariesPerComputer"

$headers=New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$headersv2=New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headersv2.Add("X-Neo42-Auth", "Admin")
$headersv2.Add("X-Neo42-ControllerVersion", "2")

$rawComputerTargets = Invoke-RestMethod -Method Get -Uri $wsusComputerTargetUrl -Headers $headersv2 -UseDefaultCredentials
$computerTargets = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach($target in $rawComputerTargets)
{
    $computerTargets.Add($target.Id, $target)
}

$updateSummaries = Invoke-RestMethod -Method Get -Uri $wsusUpdateSummariesPerComputerTargetUrl -Headers $headers -UseDefaultCredentials

$output = New-Object Collections.Generic.List[System.Object]
foreach($updateSummary in $updateSummaries)
{
    $report = $computerTargets[$($updateSummary.ComputerTarget)]
    if($null -eq $report)
    {
        continue
    }

    $obj = New-Object System.Object
    $obj | Add-Member -type NoteProperty -name FQDN -value $report.FullDomainName
    $obj | Add-Member -type NoteProperty -name ComputerRole -value $report.ComputerRole
    $obj | Add-Member -type NoteProperty -name LastReportedStatusTime -value $report.LastReportedStatusTime
    $obj | Add-Member -type NoteProperty -name LastSyncTime -value $report.LastSyncTime
    $obj | Add-Member -type NoteProperty -name Failed -value $updateSummary.FailedCount
    $obj | Add-Member -type NoteProperty -name Installed -value $updateSummary.InstalledCount
    $obj | Add-Member -type NoteProperty -name InstalledPendingReboot -value $updateSummary.InstalledPendingRebootCount

    $output.Add($obj)
}

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default