<#
.SYNOPSIS
    Renames an Application in ConfigMgr
.DESCRIPTION
    Renames an Application in ConfigMgr
.PARAMETER NewName
    The new name of the Application
.PARAMETER CI_UniqueID
    The CI_UniqueID of the Application to rename
    Format: ScopeID:ApplicationID:Revision
.PARAMETER SiteServer
    The SiteServer of the ConfigMgr Site
.PARAMETER SiteCode
    The SiteCode of the ConfigMgr Site
.PARAMETER SubProcess
    Internal parameter to run the script as a subprocess
.EXAMPLE
    RenameCMApplication.ps1 -NewName "New Name" -CI_UniqueID "ScopeID:ApplicationID:Revision" -SiteServer "SiteServer" -SiteCode "SiteCode"
.EXAMPLE
    APC specific example
    -NewName "Prefix_<Run.Developer> <Run.Product> <Run.Version>" -CI_UniqueID "<Run.ConfigMgrApplicationUniqueId>" -SiteServer "<Global.SiteServer>" -SiteCode "<Global.SiteCode>"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]
    $NewName,
    [Parameter(Mandatory=$true)]
    [string]
    $CI_UniqueID,
    [Parameter(Mandatory=$true)]
    [string]
    $SiteServer,
    [Parameter(Mandatory=$true)]
    [string]
    $SiteCode,
    [Parameter()]
    [switch]
    $SubProcess = $false
)
[string]$scriptName = Split-Path -Path $MyInvocation.MyCommand.Path -Leaf
if ($false -eq $SubProcess){
    [string]$scriptPath = $MyInvocation.MyCommand.Definition
    [string]$arguments = ForEach ($PSBoundParameter in $PsBoundParameters.GetEnumerator()){
        [string]$key = $PSBoundParameter.Key;
        [string]$value = $PSBoundParameter.Value;
        " -$Key `"$Value`""
    }
    [string]$commandArguments = "-NoProfile"+" -ExecutionPolicy"+" Bypass"+" -File"+" `"$scriptPath`""+" -Subprocess"+$arguments
    [System.Diagnostics.Process]$process = Start-Process powershell.exe -PassThru -wait -ArgumentList $commandArguments
    $process | select *
    if ($process.ExitCode -ne 0){
        Write-Error "Process exited with error"
        exit -1
    }
    exit 0
}
[string]$modelName = "$(($CI_UniqueID -split ":")[0])/$(($CI_UniqueID -split ":")[1])"
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer
}
Set-Location "$($SiteCode):\"
Add-Content -Path "$PSScriptRoot\${scriptName}.log" -Value "$(Get-Date -Format '[dd.MM.yyyy HH:mm:ss]'): Try to rename App with ModelID $($ModelName) to $($NewName)"
Set-CMApplication -ModelName $ModelName -NewName $NewName -ErrorAction Stop
Add-Content -Path "$PSScriptRoot\${scriptName}.log" -Value "$(Get-Date -Format '[dd.MM.yyyy HH:mm:ss]'): Successfully renamed App with ModelID $($ModelName) to $($NewName)"
