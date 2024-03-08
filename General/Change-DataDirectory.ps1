#requires -version 5.1
<#
.SYNOPSIS
    Changes the data directory for the Server and all Microservices
.DESCRIPTION
    Changes the data directory and migrates the data to the new directory. 
    Caution: The service must be stopped for the operation.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  19.10.2023
    Change Date:    08.03.2024
    Purpose/Change: Formatting
  
.EXAMPLE
    .\Change-DataDirectory.ps1
#>

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

$serviceName = "Neo42MgmtSvc"
$service = Get-Service -Name $serviceName
if ($service.Status -ne "Stopped") {
    Write-Error "Service Neo42MgmtSvc must be stopped."
    exit
} 

$servicePathName = [string]::Empty

$servicePathName = (Get-CimInstance win32_service | Where-Object { $_.Name -like $serviceName } | Select-Object PathName).PathName.Replace("""", "")
$appConfigDllPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($servicePathName), "plugins\Neo42.WebService.PlugIn\Neo42.WebService.PlugIn.dll")
$appConfig = [System.Configuration.ConfigurationManager]::OpenExeConfiguration($appConfigDllPath)
$oldPath = [System.Environment]::ExpandEnvironmentVariables($appConfig.AppSettings.Settings["ApplicationBaseDirectory"].Value)
if ((Test-Path -Path  $oldPath) -eq $false) {
    Write-Error "Configured data directory does not exist."
    exit
}

Write-Host "Current data directory is '$oldPath'."

$folderBrowserDialog = New-Object -typename System.Windows.Forms.FolderBrowserDialog
$folderBrowserDialog.RootFolder = "MyComputer"
$folderBrowserDialog.Description = "Select data folder"
$folderBrowserDialog | Get-Member | Where-Object { $_.Name -eq "UseDescriptionForTitle" }
if ($null -ne ($folderBrowserDialog | Get-Member | Where-Object { $_.Name -eq "UseDescriptionForTitle" })) {
    $folderBrowserDialog.UseDescriptionForTitle = $true
}

$result = $folderBrowserDialog.ShowDialog()
if ($result -ne 'OK') {
    Write-Error "Invalid path."  
    exit  
}

$newPath = $folderBrowserDialog.SelectedPath
Write-Host "Selected data directory is '$newPath'."

if ($oldPath -eq $newPath) {
    Write-Error "New data directory cannot be the current one."
    exit
}

if ($newPath.StartsWith($oldPath, [System.StringComparison]::OrdinalIgnoreCase) -eq $true) {
    Write-Error "New data directory cannot be a subfolder of the current one."
    exit
}

$msgBoxResult = [System.Windows.Forms.MessageBox]::Show("Do you really want to use '$newPath' as the new data directory?", [string]::Empty, 4, [System.Windows.Forms.MessageBoxIcon]::Question)
if ($msgBoxResult -eq "No") {
    exit
}

$oldPathSize = (Get-ChildItem -Path $oldPath -Recurse | Measure-Object -Property Length -Sum).Sum
$newPathFreespace = (New-Object System.IO.DriveInfo ([System.IO.Path]::GetPathRoot($newPath))).AvailableFreeSpace
if (
    ([System.IO.Path]::GetPathRoot($oldPath) -ne [System.IO.Path]::GetPathRoot($newPath)) -and 
    ($oldPathSize -gt $newPathFreespace)
) {
    Write-Error "There is not enough free space on the target drive to migrate the data."
    exit
}

$hasError = $false
try {
    Write-Host "Migrating data from '$oldPath' to '$newPath'..."
    Get-ChildItem -Path $oldPath -Recurse | Move-Item -Destination $newPath
}
catch {
    $hasError = $true
    Write-Error ("An error occurred while migrating the data:" + ([System.Environment]::NewLine) + $_.ToString())
}
finally {
    if ($hasError -eq $false) {
        $newPathSize = (Get-ChildItem -Path $newPath -Recurse | Measure-Object -Property Length -Sum).Sum
        if ($oldPathSize -ne $newPathSize) {
            Write-Error "Data migration failed. Size of the new data directory isn't equal to the size of the old data directory."
            exit
        }

        Write-Host "Data successfully migrated."
        $appConfig.AppSettings.Settings["ApplicationBaseDirectory"].Value = $newPath
        $appConfig.Save()

        (Get-Content -Raw -Path ([System.IO.Path]::Combine($newPath, "MongoDb\mongod.cfg"))) `
            -replace "(?<=path:)\s*$([Regex]::Escape($oldPath))(?=\\MongoDb\\logs\\mongod\.log)", " $newPath" `
            -replace "(?<=dbPath:)\s*$([Regex]::Escape($oldPath))(?=\\MongoDb\\data\\db\\V5)", " $newPath" |
            Set-Content -Path ([System.IO.Path]::Combine($newPath, "MongoDb\mongod.cfg"))
    }
}