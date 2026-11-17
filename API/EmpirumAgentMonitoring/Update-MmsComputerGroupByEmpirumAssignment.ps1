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
	Purpose/Change:			Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
	Required MMS Server:	2.8.5.0
.EXAMPLE
	.\Update-MmsComputerGroupByEmpirumAssignment.ps1 -ServerName "https://server.domain:4242" -FilterName "Empirum Package Assignment" -EmpirumDBServer "EmpirumServer\Instance" -EmpirumDBName "EmpirumDB" -EmpirumPackageName "Package Name"
#>
[CmdletBinding(SupportsShouldProcess)]
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
	$EmpirumPackageName
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

# Testing for required Module
if ($null -eq (Get-Command -Name Invoke-Sqlcmd)) {
	Write-Warning "
SqlServer Module not available. To install the SqlServer Module run the following command:`n
Install-Module SqlServer"
	Start-Sleep 10
	exit 1
}

# Load the filter to edit. Get-MmsFilter -Name parses the Criteria json and
# matches on the name inside it, and adds the parsed form as CriteriaObject.
$targetFilter = Get-MmsFilter -Name $FilterName | Select-Object -First 1

if ($null -eq $targetFilter) {
	Write-Error "No filter found with name '$FilterName'"
	Exit 1
}

$criteriaParsed = $targetFilter.CriteriaObject

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

Write-Verbose ("Clients to write into the filter:`n" + ($empClients -join "`n"))

# Update filter. Run with -WhatIf to see the request without sending it.
Set-MmsFilter -Filter $targetFilter -Criteria $criteriaParsed -Confirm:$false
