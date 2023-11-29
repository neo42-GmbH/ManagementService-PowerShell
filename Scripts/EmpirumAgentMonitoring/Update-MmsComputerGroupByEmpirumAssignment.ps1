#requires -Version 5
#+Requires -Modules SqlServer
<#
.SYNOPSIS
    Updates a MMS filter based on empirum software assignments
.DESCRIPTION
    This script updates an existing MMS "Computer group" filter based on empirum software assignments.
    The target filter must already exist. Can be used as a scheduled task to ensure a regular filter update.
    During the first implementation tests, please use filters that are not yet used productively.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:             1.1
    Author:              neo42 GmbH
    Creation Date:       30.11.2021
    Purpose/Change:      Initial version
    Required MMS Server: 2.8.5.0
.COMPONENT
    neo42 Management Service 
.EXAMPLE
    .\Update-MmsComputerGroupByEmpirumAssignment.ps1 
#>

# Fill with current servername
$servername = 'https://HYD-DEV2.corp.contoso.com:443'

# Name of the target mms filter
$filterToEdit = "Test Clients"

# Fill with Empirum sql server name and database
$empdbserver = "EMP1\SQLEXPRESS"
$empdatabase = "EmpirumDB"

# Display name of the target empirum package
$empirumPackageName = "Empirum Inventory 20.0"

# Set $ReadOnly to $false, to actually perform changes to the targeted System
$ReadOnly = $false

function Test-IsGuid
{
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$StringGuid
    )
 
   $objectGuid = [System.Guid]::Empty
   return [System.Guid]::TryParse($StringGuid,[System.Management.Automation.PSReference]$objectGuid)
}

# Setup header
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")

# Load all filter and detect filter to edit
$filterList = Invoke-RestMethod -Method Get -Uri $servername/api/criteriastorev3 -Headers $headers -UseDefaultCredentials
$targetFilter = $null
$criteriaParsed = $null

foreach($filter in $filterList)
{
    $criteriaParsed = $filter.Criteria | ConvertFrom-Json 
    
    if($criteriaParsed.Name -eq $filterToEdit)
    {
        $targetFilter = $filter
    }
}

if($null -eq $targetFilter)
{
    Write-Error "No filter found with name '$filterToEdit'"
    Exit 
}

$criteriaParsed = ConvertFrom-Json $targetFilter.Criteria

if(($targetFilter.Type -ne 3))
{
    Write-Error "Filter is not from type 'ComputernameList'. Current filter type: '$($criteriaParsed.Type)'"
    Exit 
}

# Search target package in empirum database
$query = "Select SoftwareID From Software where SoftwareName = '$empirumPackageName'"
$empirumPackage = Invoke-Sqlcmd -Query $query -ServerInstance $empdbServer -Database $empdatabase

if(!(Test-IsGuid -StringGuid $empirumPackage.SoftwareID))
{
    Write-Error "No empirum package found with name '$empirumPackageName'"
    Exit 
}

# Load all clients with target package assignments
$query = "SELECT [Name] FROM dbo.STfncGetSwCliState(3, '$($empirumPackage.SoftwareID)', '00000000-0000-0000-0000-000000000000')"
$empClients = Invoke-Sqlcmd -Query $query -ServerInstance $empdbServer -Database $empdatabase | ForEach-Object { "$($_.name)" -replace " ", "" }

# Set filter content to clientlist
$criteriaParsed.Data.ComputernameList = $empClients
$targetFilter.Criteria = ConvertTo-Json $criteriaParsed -Compress

# Update filter
if(!$ReadOnly){
    Invoke-RestMethod -Method Post -Uri $servername/api/criteriastorev3 -Headers $headers -UseDefaultCredentials -Body ($targetFilter | ConvertTo-Json) -ContentType "application/json; charset=utf-8"
}else{
    Write-Output "ReadOnly Mode detected, would send the follwoing request on `$Readonly=`$false"
    Write-Output "Url= $servername/api/criteriastorev3"
    Write-Output $("Clients: $empClients" -replace " ","`n")
    Start-Sleep 10
}
