<#
.SYNOPSIS
This script updates a JSON file.
.DESCRIPTION
This script reads a JSON file, updates a property, and saves the changes back to the file.
.PARAMETER Path
The path to the JSON file.
.EXAMPLE
Disable-BlockExecution.ps1 -Path "C:\example.json"
#>
Param(
    [Parameter(Mandatory=$true)]
    [System.IO.FileInfo]
    [ValidateScript({ $_.exists -and $_.extension -eq ".json" })]
    $Path
)
[pscustomobject]$jsonData = Get-Content -Path $Path -Raw | ConvertFrom-Json
## Update the JSON object as needed here, to demonstrate, we will set the BlockExecution property to false
## To update a property, you can use the following syntax:
$jsonData.BlockExecution = $false
$jsonData | ConvertTo-Json -Depth 100 | Set-Content -Path $Path
## Duplicate this script and modify it to use it in different scenarios
