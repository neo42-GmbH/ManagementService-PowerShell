<#
.SYNOPSIS
	Merge provided files, folders or logos to the PSADT package
.DESCRIPTION
	Script to copy files, folders or logos to neo42 PSADT package
	PSADT v3 (PackageFramework 3.0):
		Uses the product folders below <GlobalGeneralDirectory>\CustomFiles and copies the logos into the AppDeployToolkit directory of the package.
	PSADT v4 (PackageFramework 4.0):
		Uses the product folders below <GlobalGeneralDirectory>\CustomFiles\4.0. As long as the Files or SupportFiles folder of a 4.0 product folder does not exist, it is created as a complete copy of the same folder of the v3 product folder. Afterwards both product folders are maintained independently.
		The logos are delivered through the package directory Overrides.Branding, which only carries the logos and their Config\config.psd1. The accent color is set by Set-AccentColor.ps1 in its own Overrides.AccentColor directory, so both scripts never overwrite each other.
.PARAMETER PackagePath
	The PackagePath of the neo42 APC PSADT working directory
.PARAMETER GlobalGeneralDirectory
	The directory where package assets are stored. Example Global.GeneralDirectory = C:\neo42\General
	Please create this pipeline variable in APC menu 'Configuration / Pipelinevariable'
.PARAMETER PackageFramework
	The package framework of the package as provided by the pipeline variable <Run.PackageFramework>. Supported values are 3.0 and 4.0.
	For 0.1, a package without toolkit such as a neo42 tool, nothing is done and the task succeeds.
.EXAMPLE
	APC specific example
	-PackagePath "<Phase.PackagePath>\<Run.Version>" -GlobalGeneralDirectory "<Global.GeneralDirectory>" -PackageFramework "<Run.PackageFramework>"
.OUTPUTS
	Protocol lines as strings
.NOTES
	Creation Date:			09.09.2026
	Tested on:				MMS Server 5.0.0
#>

[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[System.IO.DirectoryInfo]
	$PackagePath,
	[Parameter(Mandatory = $true)]
	[ValidateScript({$_.ToString() -match '^([A-Za-z]:[\\/]|[\\/]{2})'})]
	[System.IO.DirectoryInfo]
	$GlobalGeneralDirectory,
	[Parameter(Mandatory = $true)]
	[version]
	$PackageFramework
)

## [System.IO.File]::Copy refuses to overwrite a read-only, hidden or system file and passes these attributes on, which would break every later run
function Copy-FileOverwrite {
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Source,
		[Parameter(Mandatory = $true)]
		[string]
		$Destination
	)
	[System.IO.FileAttributes]$blockingAttributes = [System.IO.FileAttributes]::ReadOnly -bor [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
	if ([System.IO.File]::Exists($Destination)) {
		[System.IO.File]::SetAttributes($Destination, [System.IO.File]::GetAttributes($Destination) -band -bnot $blockingAttributes)
	}
	[System.IO.File]::Copy($Source, $Destination, $true)
	[System.IO.File]::SetAttributes($Destination, [System.IO.File]::GetAttributes($Destination) -band -bnot $blockingAttributes)
}

## Uses literal paths, because Copy-Item -Path treats [ ] in product names as wildcards and silently copies nothing
function Copy-DirectoryContent {
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Source,
		[Parameter(Mandatory = $true)]
		[string]
		$Destination
	)
	[System.IO.Directory]::CreateDirectory($Destination) | Out-Null
	foreach ($sourceDirectory in [System.IO.Directory]::GetDirectories($Source, '*', [System.IO.SearchOption]::AllDirectories)) {
		[System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($Destination, $sourceDirectory.Substring($Source.Length).TrimStart('\'))) | Out-Null
	}
	foreach ($sourceFile in [System.IO.Directory]::GetFiles($Source, '*', [System.IO.SearchOption]::AllDirectories)) {
		Copy-FileOverwrite -Source $sourceFile -Destination ([System.IO.Path]::Combine($Destination, $sourceFile.Substring($Source.Length).TrimStart('\')))
	}
}

## Read-only entries make [System.IO.Directory]::Delete fail after it already removed everything else. Junctions are removed as links,
## their targets lie outside the package and are neither changed nor deleted.
function Remove-DirectoryForced {
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)
	[System.IO.DirectoryInfo]$directory = [System.IO.DirectoryInfo]::new($Path)
	if ($directory.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
		[System.IO.File]::SetAttributes($Path, [System.IO.File]::GetAttributes($Path) -band -bnot [System.IO.FileAttributes]::ReadOnly)
		[System.IO.Directory]::Delete($Path, $false)
		return
	}
	foreach ($entry in $directory.GetFileSystemInfos()) {
		if ($entry -is [System.IO.DirectoryInfo]) {
			Remove-DirectoryForced -Path $entry.FullName
		}
		else {
			$entry.Attributes = [System.IO.FileAttributes]::Normal
			$entry.Delete()
		}
	}
	$directory.Attributes = [System.IO.FileAttributes]::Directory
	$directory.Delete()
}

## A byte order mark decides the encoding. Without one the file is read as UTF-8 if it is valid UTF-8, otherwise as ANSI.
function Read-TextFile {
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)
	[System.Text.Encoding]$encoding = [System.Text.Encoding]::Default
	try {
		[System.Text.UTF8Encoding]::new($false, $true).GetString([System.IO.File]::ReadAllBytes($Path)) | Out-Null
		$encoding = [System.Text.UTF8Encoding]::new($false)
	}
	catch [System.Text.DecoderFallbackException] {
	}
	[System.IO.StreamReader]$reader = [System.IO.StreamReader]::new($Path, $encoding, $true)
	try {
		$reader.ReadToEnd()
	}
	finally {
		$reader.Dispose()
	}
}

## -ErrorAction Stop or SilentlyContinue in the task arguments would otherwise turn the Write-Error below into a reported success
$ErrorActionPreference = 'Continue'

## The pipeline task only fails on records in the error stream, a terminating error alone is reported as success
try {
	if ($PackageFramework -eq [version]'0.1') {
		Write-Output "PackageFramework $PackageFramework is a package without toolkit, nothing to do."
		return
	}
	if ($false -eq $PackagePath.Exists) {
		throw "The package path '$($PackagePath.FullName)' does not exist."
	}
	switch ($PackageFramework) {
		([version]'3.0') {
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

			# Copy custom CI logos to PSADT V3 package AppDeployToolkit directory
			Copy-Item -Path $logos -Recurse -Destination $appDeployToolkit -Force

			# Copy provided files or folders to the PSADT package
			$copyExistDirectoryFiles = @($appDeployToolkit, $files, $supportFiles)
			Copy-Item -Path $copyExistDirectoryFiles -Recurse -Destination $PackagePath -Force
			break
		}
		([version]'4.0') {
			# Set path variables
			[string]$customFiles = [System.IO.Path]::Combine($GlobalGeneralDirectory.FullName, 'CustomFiles')
			[string]$directoryLogos = [System.IO.Path]::Combine($GlobalGeneralDirectory.FullName, 'Logos')

			# PackageName determination from neo42PackageConfig.json
			[string]$packageConfigPath = [System.IO.Path]::Combine($PackagePath.FullName, 'neo42PackageConfig.json')
			$packageConfig = Read-TextFile -Path $packageConfigPath | ConvertFrom-Json
			[string]$packageName = "$($packageConfig.AppVendor) $($packageConfig.AppName)"
			## The v3 branch names its product folder from Get-Content, which reads a config without byte order mark as ANSI.
			## The migration has to look for the v3 folder under that name, or non-ASCII product names would never be found.
			$v3PackageConfig = Get-Content -LiteralPath $packageConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json
			[string]$v3PackageName = "$($v3PackageConfig.AppVendor) $($v3PackageConfig.AppName)"

			# Set directory variables
			[string]$v3ProductFolder = [System.IO.Path]::Combine($customFiles, $v3PackageName)
			[string]$v4ProductFolder = [System.IO.Path]::Combine($customFiles, $PackageFramework, $packageName)
			[string]$v4BrandingAssets = [System.IO.Path]::Combine($v4ProductFolder, 'Overrides.Branding', 'Assets')
			[string]$v4Files = [System.IO.Path]::Combine($v4ProductFolder, 'Files')
			[string]$v4SupportFiles = [System.IO.Path]::Combine($v4ProductFolder, 'SupportFiles')
			[string]$v4UserSupportFiles = [System.IO.Path]::Combine($v4ProductFolder, 'SupportFiles', 'User')

			## Migrate the PSADT V3 Files and SupportFiles only while the 4.0 folder does not exist yet, so items deleted from it later stay deleted.
			## Each run copies to its own staging folder that is renamed when complete: an aborted migration is repeated by the next run,
			## and of two runs migrating the same product at once only the first complete copy is kept. The staging folder sits directly
			## below CustomFiles\4.0, so its path is never longer than the final one; the service process does not support long paths.
			foreach ($folderName in @('Files', 'SupportFiles')) {
				[string]$v3Folder = [System.IO.Path]::Combine($v3ProductFolder, $folderName)
				[string]$v4Folder = [System.IO.Path]::Combine($v4ProductFolder, $folderName)
				if ([System.IO.Directory]::Exists($v4Folder)) {
					continue
				}
				if (-not [System.IO.Directory]::Exists($v3Folder)) {
					Write-Output "There is no '$v3Folder' to migrate, '$v4Folder' starts empty."
					continue
				}
				[string]$stagingFolder = [System.IO.Path]::Combine($customFiles, $PackageFramework, "~$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))")
				try {
					Copy-DirectoryContent -Source $v3Folder -Destination $stagingFolder
					[System.IO.Directory]::CreateDirectory($v4ProductFolder) | Out-Null
					try {
						[System.IO.Directory]::Move($stagingFolder, $v4Folder)
						Write-Output "Migrated '$v3Folder' to '$v4Folder'."
					}
					catch [System.IO.IOException] {
						if (-not [System.IO.Directory]::Exists($v4Folder)) {
							throw
						}
						Write-Output "'$v4Folder' was migrated by another run in the meantime."
					}
				}
				finally {
					## A failing cleanup must not replace the error that ended the migration
					if ([System.IO.Directory]::Exists($stagingFolder)) {
						try {
							Remove-DirectoryForced -Path $stagingFolder
						}
						catch {
							Write-Warning -Message "The staging folder '$stagingFolder' could not be removed: $($_.Exception.Message)"
						}
					}
				}
			}

			# Create directories when directories do not exist
			[string[]]$directoriesToCreate = @(
				$customFiles,
				$directoryLogos,
				$v4BrandingAssets,
				$v4Files,
				$v4SupportFiles,
				$v4UserSupportFiles
			)

			foreach ($dir in $directoriesToCreate) {
				if (-not [System.IO.Directory]::Exists($dir)) {
					[System.IO.Directory]::CreateDirectory($dir) | Out-Null
					Write-Verbose -Message "Created directory: $dir"
				}
			}

			# Define mapping: OriginalName = TargetName
			[System.Collections.Specialized.OrderedDictionary]$fileMapping = [ordered]@{
				'CustomAppDeployToolkitBanner.png'      = 'Banner.Classic.png'
				'CustomAppDeployToolkitBanner_dark.png' = 'Banner.Classic.Dark.png'
				'CustomAppDeployToolkitLogo.png'        = 'Logo.png'
			}

			# Iterate through the mapping and copy files with new names
			foreach ($entry in $fileMapping.GetEnumerator()) {
				[string]$sourceFilePath = [System.IO.Path]::Combine($directoryLogos, $entry.Key)
				[string]$destinationFilePath = [System.IO.Path]::Combine($v4BrandingAssets, $entry.Value)

				if ([System.IO.File]::Exists($sourceFilePath)) {
					Copy-FileOverwrite -Source $sourceFilePath -Destination $destinationFilePath
					Write-Verbose -Message "Successfully copied '$($entry.Key)' to '$($entry.Value)'"
				}
				else {
					Write-Warning -Message "Source file was not found: $sourceFilePath. The logo '$($entry.Value)' in '$v4BrandingAssets' is used if present."
				}
			}

			# Copy provided custom files and folders into the PSADT V4 package structure
			Copy-DirectoryContent -Source $v4Files -Destination ([System.IO.Path]::Combine($PackagePath.FullName, 'Files'))
			Copy-DirectoryContent -Source $v4SupportFiles -Destination ([System.IO.Path]::Combine($PackagePath.FullName, 'SupportFiles'))

			## The toolkit ignores the Assets of an Overrides directory without a Config\config.psd1, so the config is written last
			## and only lists logos that were actually copied. A previous Overrides.Branding is discarded first, otherwise stale
			## logos of an earlier run would still be picked up.
			[string]$brandingPath = [System.IO.Path]::Combine($PackagePath.FullName, 'Overrides.Branding')
			if ([System.IO.Directory]::Exists($brandingPath)) {
				Remove-DirectoryForced -Path $brandingPath
				Write-Verbose -Message "Removed existing directory '$brandingPath'."
			}

			[System.Collections.Specialized.OrderedDictionary]$brandingAssetKeys = [ordered]@{
				'Logo'       = 'Logo.png'
				'Banner'     = 'Banner.Classic.png'
				'BannerDark' = 'Banner.Classic.Dark.png'
			}
			[string[]]$availableAssetKeys = @($brandingAssetKeys.Keys | Where-Object { [System.IO.File]::Exists([System.IO.Path]::Combine($v4BrandingAssets, $brandingAssetKeys[$_])) })

			if ($availableAssetKeys.Count -gt 0) {
				[string]$brandingAssetsPath = [System.IO.Path]::Combine($brandingPath, 'Assets')
				[string]$brandingConfigPath = [System.IO.Path]::Combine($brandingPath, 'Config')
				[System.IO.Directory]::CreateDirectory($brandingAssetsPath) | Out-Null
				[System.IO.Directory]::CreateDirectory($brandingConfigPath) | Out-Null

				[string[]]$assetLines = foreach ($assetKey in $availableAssetKeys) {
					[string]$assetFileName = $brandingAssetKeys[$assetKey]
					Copy-FileOverwrite -Source ([System.IO.Path]::Combine($v4BrandingAssets, $assetFileName)) -Destination ([System.IO.Path]::Combine($brandingAssetsPath, $assetFileName))
					"`t`t{0,-11} = '..\Assets\{1}'" -f $assetKey, $assetFileName
				}

				[string]$brandingConfigContent = "@{`r`n`tAssets = @{`r`n" + ($assetLines -join "`r`n") + "`r`n`t}`r`n}`r`n"
				[string]$brandingConfigFile = [System.IO.Path]::Combine($brandingConfigPath, 'config.psd1')
				[System.IO.File]::WriteAllText($brandingConfigFile, $brandingConfigContent, [System.Text.UTF8Encoding]::new($true))
				Write-Output "Logos '$($availableAssetKeys -join "', '")' were written to '$brandingPath'."
			}
			else {
				Write-Warning -Message "No logos were found in '$v4BrandingAssets', the package keeps its own logos."
			}
			break
		}
		Default {
			Write-Error -Message "PackageFramework Version $PackageFramework is not supported."
		}
	}
}
catch {
	Write-Error $_.Exception.Message
	exit 1
}
