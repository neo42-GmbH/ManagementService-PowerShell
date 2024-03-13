#requires -version 5
<#
.SYNOPSIS
	Exports a list of all clients where the Empirum Agent Framework is not active
.DESCRIPTION
	An Example to show how to interact with the neo42 Management Service Api
	to export a list of all clients where the Empirum Agent Framework is not active.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER OutputPath
	The path where the csv files should be stored.
	Defaults to the script root.
.OUTPUTS
	none
.NOTES
	Version:        1.0
	Author:         neo42 GmbH
	Creation Date:  30.11.2023
	Purpose/Change: Initial version
.EXAMPLE
	.\Export-EmpirumAgentWithInactiveFramework.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
    [parameter(Mandatory = $true)]
    [String]
    $ServerName,
    [parameter(Mandatory = $false)]	
    [String]
    $OutputPath = "$PSScriptRoot"
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "EmpirumAgentMonitoringReports.csv"

$clientUrl = "$ServerName/api/Client"
$empirumReportUrl = "$ServerName/api/EmpirumMonitoringReportV2"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$clientsRaw = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$clientsDict = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach ($client in $clientsRaw) {
    $clientsDict.Add($client.Id, ($client | Select-Object -Property NetBiosName, Id))
}

$reports = Invoke-RestMethod -Method Get -Uri $empirumReportUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$inactiveClients = $reports | Where-Object { $_.Report.UafActive -eq $false } | 
Select-Object -Property @{Name = 'Client'; Expression = { $clientsDict[$_.Report.ClientId].NetBiosName } },
@{Name = 'ReportTime'; Expression = { $_.Report.CollectionTime } }, 
@{Name = 'UafInstalled'; Expression = { $_.Report.UafInstalled } }, 
@{Name = 'EmpirumLastContact'; Expression = { $_.EmpirumData.LastLogDate } }

$inactiveClients | Export-Csv -Path $filePath -NoClobber -NoTypeInformation -Encoding Default