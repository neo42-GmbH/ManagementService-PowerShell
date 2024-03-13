<#

.SYNOPSIS
	Merge provided files, folders or logos to the PSADT package
.DESCRIPTION
	Script to copy files, folders or logos to neo42 PSADT package
.PARAMETER $PackagePath
	The PackagePath of the neo42 APC PSADT working directory  
.PARAMETER $GlobalGeneralDirectory	
	The General directory of the neo42 directory
.OUTPUTS
	none
.NOTES
	Author:					alf.palmroth@neo42.de
	Creation Date:			08.03.2004
	Required MMS Server:	4.0.16

#>

[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$PackagePath,
	[parameter(Mandatory = $true)]
	[String]
	$GlobalGeneralDirectory		
)

## Please create global Pipelinevariable <Global.GeneralDirectory> in APC menu Configuration / Pipelinevariable
## Example <Global.GeneralDirectory> Value = C:\neo42\General

# Set path variables
$CustomFiles = "$GlobalGeneralDirectory\CustomFiles\"
$DirectoryLogos = "$GlobalGeneralDirectory\Logos\"
$Logos = "$GlobalGeneralDirectory\Logos\*.png"

# PackageName determination from neo42PackageConfig.json #
$PackageConfig=Get-Content -Raw "$PackagePath\neo42PackageConfig.json" |ConvertFrom-Json
$PackageName = "$($packageconfig.AppVendor) $($packageconfig.AppName)"

# Set directory variables
$AppDeployToolkit = "$CustomFiles\$PackageName\AppDeployToolkit\"
$Files = "$CustomFiles\$PackageName\Files\"
$SupportFiles = "$CustomFiles\$PackageName\SupportFiles\"
$UserSupportFiles = "$CustomFiles\$PackageName\SupportFiles\User"

# Create directories when directories not exists
$CheckExistDirectory = @($CustomFiles, $DirectoryLogos, $AppDeployToolkit, $Files, $SupportFiles, $UserSupportFiles)

foreach ($directory in $CheckExistDirectory){
	if (!(Test-Path -Path $directory)){
		New-Item -Path $directory -ItemType Directory
	}

}

# Copy custom CI logos to PSADT Package AppDeployToolkit directory
Copy-Item -Path $Logos -Recurse -Destination $AppDeployToolkit -Force

# Copy provided files or folders to the PSADT package
$CopyExistDirectoryFiles = @($AppDeployToolkit, $Files, $SupportFiles, $UserSupportFiles)

foreach ($directoryfiles in $CopyExistDirectoryFiles){
	Copy-Item -Path $CopyExistDirectoryFiles -Recurse -Destination $PackagePath -Force
}


