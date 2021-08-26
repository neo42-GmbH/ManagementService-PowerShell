#requires -version 4
<#
.SYNOPSIS
    Export a single BitLocker Report
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values for a given client from BitLocker to csv.
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
    .\Export-BitLockerReportByClient.ps1 -Domain corp -ClientName client
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
$filename = "$($PSScriptRoot)\BitlockerReport.csv"

$clientByNameUrl = "$servername/api/clientbyname/$((New-Guid).Guid)?domainName=$($Domain)&computerName=$($ClientName)"
$bitlockerReportUrl = "$servername/api/BitlockerReport/{CLIENTID}"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")
$headersv3=New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headersv3.Add("X-Neo42-Auth", "Admin")
$headersv3.Add("X-Neo42-ControllerVersion", "3")

$client = Invoke-RestMethod -Method Get -Uri $clientByNameUrl -Headers $headers -UseDefaultCredentials

if($null -eq $client)
{
    Write-Warning "No client found for $($Domain)\$($ClientName)"
    Exit
}

$report = Invoke-RestMethod -Method Get -Uri $bitlockerReportUrl.Replace("{CLIENTID}","$($client.Id)") -Headers $headersv3 -UseDefaultCredentials
$output = New-Object Collections.Generic.List[System.Object]
if($null -eq $report)
{
    Write-Warning "No drive monitoring report found for $($Domain)\$($ClientName)"
    Exit
}

$Compliancestates = New-Object "System.Collections.Generic.Dictionary[[Int],[String]]"
$Compliancestates[0]="No Report"
$Compliancestates[1]="Not Compliant"
$Compliancestates[2]="Compliant"

$obj = New-Object System.Object
$obj | Add-Member -type NoteProperty -name Client -value $client.NetBiosName
$obj | Add-Member -type NoteProperty -name ReportDate -value $report.CreationDate
$obj | Add-Member -type NoteProperty -name State -value $Compliancestates[$report.ComplianceState]
$obj | Add-Member -type NoteProperty -name CurrentEncryptionTries -value $report.CurrentEncryptionTriesCount
$obj | Add-Member -type NoteProperty -name MaxEncryptionTries -value $report.MaxEncryptionTriesCount

$output.Add($obj)

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default