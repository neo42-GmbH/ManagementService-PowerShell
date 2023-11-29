#requires -Version 5
#+Requires -Modules SqlServer
<#
.SYNOPSIS
	Updates a MMS filter based on empirum software assignments
.DESCRIPTION
	This script updates an existing MMS "Computer group" filter based on empirum software assignments.
	The target filter must already exist. Can be used as a scheduled task to ensure a regular filter update.
	During the first implementation tests, please use filters that are not yet used productively.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER FilterName
	The name of the filter to update.
.PARAMETER EmpirumDBServer
	The servername of the Empirum database in the format "Server\Instance".
.PARAMETER EmpirumDBName
	The name of the Empirum database.
.PARAMETER EmpirumPackageName
	The name of the Empirum package to search for.
.PARAMETER WhatIf
	Shows what would happen if the script would be executed.
.OUTPUTS
	none
.NOTES
	Version:				1.2
	Author:					neo42 GmbH
	Creation Date:			30.11.2023
	Purpose/Change:			Initial version
	Required MMS Server:	2.8.5.0
.EXAMPLE
	.\Update-MmsComputerGroupByEmpirumAssignment.ps1 -ServerName "https://server.domain:4242" -FilterName "Empirum Package Assignment" -EmpirumDBServer "EmpirumServer\Instance" -EmpirumDBName "EmpirumDB" -EmpirumPackageName "Package Name"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $true)]
	[String]
	$FilterName,
	[parameter(Mandatory = $true)]
	[String]
	$EmpirumDBServer,
	[parameter(Mandatory = $true)]
	[String]
	$EmpirumDBName,
	[parameter(Mandatory = $true)]
	[String]
	$EmpirumPackageName,
	[parameter(Mandatory = $false)]
	[switch]
	$WhatIf
)

$csUrl = "$ServerName/api/criteriastorev3"

# Setup header
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

# Load all filter and detect filter to edit
$filterList = Invoke-RestMethod -Method Get -Uri $csUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
$targetFilter = $null
$criteriaParsed = $null

foreach ($filter in $filterList) {
	$criteriaParsed = $filter.Criteria | ConvertFrom-Json 
	if ($criteriaParsed.Name -eq $FilterName) {
		$targetFilter = $filter
		break
	}
}

if ($null -eq $targetFilter) {
	Write-Error "No filter found with name '$FilterName'"
	Exit 1
}

if (($targetFilter.Type -ne 3)) {
	Write-Error "Filter is not from type 'ComputernameList'. Current filter type: '$($criteriaParsed.Type)'"
	Exit 1
}

# Search target package in empirum database
$query = "Select SoftwareID From Software where SoftwareName = '$EmpirumPackageName'"
$empirumPackage = Invoke-Sqlcmd -Query $query -ServerInstance $EmpirumDBServer -Database $EmpirumDBName -ErrorAction Stop

# Test if package has a valid guid
if ($false -eq [System.Guid]::TryParse($empirumPackage.SoftwareID, [System.Guid]::Empty)) {
	Write-Error "No empirum package found with name '$EmpirumPackageName'"
	Exit 1
}

# Load all clients with target package assignments
$query = "SELECT [Name] FROM dbo.STfncGetSwCliState(3, '$($empirumPackage.SoftwareID)', '00000000-0000-0000-0000-000000000000')"
$empClients = Invoke-Sqlcmd -Query $query -ServerInstance $EmpirumDBServer -Database $EmpirumDBName -ErrorAction Stop | ForEach-Object { "$($_.name)" -replace " ", "" }

# Set filter content to clientlist
$criteriaParsed.Data.ComputernameList = $empClients
$targetFilter.Criteria = ConvertTo-Json $criteriaParsed -Compress

# Update filter
if ($false -eq $WhatIf) {
	Invoke-RestMethod -Method Post -Uri $ServerName/api/criteriastorev3 -Headers $headers -UseDefaultCredentials -Body ($targetFilter | ConvertTo-Json) -ContentType "application/json; charset=utf-8"
}
else {
	Write-Output "WhatIf mode detected, would send the following request:"
	Write-Output "Url= $csUrl"
	Write-Output $("Clients: $empClients" -replace " ", "`n")
	Start-Sleep 10
}
