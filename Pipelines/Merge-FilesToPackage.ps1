<#
.SYNOPSIS
	Merge provided files, folders or logos to the PSADT package
.DESCRIPTION
	Script to copy files, folders or logos to neo42 PSADT package
.PARAMETER PackagePath
	The PackagePath of the neo42 APC PSADT working directory  
.PARAMETER GlobalGeneralDirectory	
	The directory where package assets are stored. Example Global.GeneralDirectory = C:\neo42\General
	Please create this pipeline variable in APC menu 'Configuration / Pipelinevariable'
.OUTPUTS
	none
.NOTES
	Author:					alf.palmroth@neo42.de
	Creation Date:			08.03.2024
	Tested on:				MMS Server 4.0.16
#>

[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[ValidateScript({$true -eq $_.Exists})]
	[System.IO.DirectoryInfo]
	$PackagePath,
	[Parameter(Mandatory = $true)]
	[ValidateScript({$true -eq [System.IO.Path]::IsPathRooted($_.FullName)})]
	[System.IO.DirectoryInfo]
	$GlobalGeneralDirectory		
)

# Set path variables
$customFiles = "$GlobalGeneralDirectory\CustomFiles\"
$directoryLogos = "$GlobalGeneralDirectory\Logos\"
$logos = "$GlobalGeneralDirectory\Logos\*.png"

# PackageName determination from neo42PackageConfig.json
$packageConfig = Get-Content -Raw "$PackagePath\neo42PackageConfig.json" -ErrorAction Stop | ConvertFrom-Json
$packageName = "$($packageconfig.AppVendor) $($packageconfig.AppName)"

# Set directory variables
$appDeployToolkit = Join-Path $customFiles "$packageName\AppDeployToolkit\"
$files = Join-Path $customFiles "$packageName\Files\"
$supportFiles = Join-Path $customFiles "$packageName\SupportFiles\"
$userSupportFiles = Join-Path $customFiles "$packageName\SupportFiles\User\"

# Create directories when directories not exists
$checkExistDirectory = @($customFiles, $directoryLogos, $appDeployToolkit, $files, $supportFiles, $userSupportFiles)
foreach ($directory in $checkExistDirectory) {
	if ($false -eq (Test-Path -Path $directory)) {
		New-Item -Path $directory -ItemType Directory
	}
	elseif ($false -eq (Test-Path -Path $directory -PathType Container)) {
		throw "The path '$directory' exists but is not a directory"
	}
}

# Copy custom CI logos to PSADT package AppDeployToolkit directory
Copy-Item -Path $logos -Recurse -Destination $appDeployToolkit -Force

# Copy provided files or folders to the PSADT package
$copyExistDirectoryFiles = @($appDeployToolkit, $files, $supportFiles)
Copy-Item -Path $copyExistDirectoryFiles -Recurse -Destination $PackagePath -Force
