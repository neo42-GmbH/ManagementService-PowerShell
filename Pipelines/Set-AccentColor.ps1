<#
.SYNOPSIS
	Set the accent color of a neo42 PSADT package
.DESCRIPTION
	Sets the accent color of the deployment dialogs of a PSADT v3 or v4 based neo42 package the same way the Corporate Identity pipeline task does.
	PSADT v3 (PackageFramework 3.0):
		Replaces the MainColor resource in AppDeployToolkit\CustomAppDeployToolkitUi.ps1. If the file carries no MainColor resource, a warning is written and the file is left unchanged.
	PSADT v4 (PackageFramework 4.0):
		Writes UI.FluentAccentColor into Overrides.AccentColor\Config\config.psd1. Both the Fluent dialogs and the neo42 legacy dialog read the accent color from this value.
		An existing Overrides.AccentColor directory is replaced. The directory only carries the accent color, so it never overwrites the logos Merge-FilesToPackage.ps1 writes to Overrides.Branding.
		If the Corporate Identity pipeline task brands the same package, its Overrides.CI directory is read after Overrides.AccentColor and its accent color wins.
.PARAMETER PackagePath
	The PackagePath of the neo42 APC PSADT working directory
.PARAMETER PackageFramework
	The package framework of the package as provided by the pipeline variable Run.PackageFramework. Supported values are 3.0 and 4.0.
	For 0.1, a package without toolkit such as a neo42 tool, nothing is done and the task succeeds.
.PARAMETER AccentColor
	The accent color, either as three RGB values from 0 to 255 separated by comma, semicolon or space, e.g. "227,0,15",
	or as a hex value with six digits and an optional '#' or '0x' prefix, e.g. "#E3000F".
	The eight digit notation with an opaque alpha channel as written in a config.psd1, e.g. "0xFFE3000F", is accepted as well.
	Always quote the value, an unquoted '#' starts a PowerShell comment.
.EXAMPLE
	Set-AccentColor.ps1 -PackagePath 'C:\Temp\Package\1.0.0' -PackageFramework '4.0' -AccentColor '#E3000F'
.EXAMPLE
	APC specific example, the pipeline variables are written in angle brackets in the task arguments
	-PackagePath "{Phase.PackagePath}\{Run.Version}" -PackageFramework "{Run.PackageFramework}" -AccentColor "227,0,15"
.OUTPUTS
	Protocol lines as strings
#>

[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[System.IO.DirectoryInfo]
	$PackagePath,
	[Parameter(Mandatory = $true)]
	[version]
	$PackageFramework,
	[Parameter(Mandatory = $true)]
	[string]
	$AccentColor
)

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

## -ErrorAction Stop or SilentlyContinue in the task arguments would otherwise turn the Write-Error below into a reported success
$ErrorActionPreference = 'Continue'

## The pipeline task only fails on records in the error stream, a terminating error alone is reported as success
try {
	if ($PackageFramework -eq [version]'0.1') {
		Write-Output "PackageFramework $PackageFramework is a package without toolkit, nothing to do."
		return
	}
	if ($PackageFramework -notin @([version]'3.0', [version]'4.0')) {
		throw "PackageFramework Version $PackageFramework is not supported."
	}
	if ($false -eq $PackagePath.Exists) {
		throw "The package path '$($PackagePath.FullName)' does not exist."
	}
	[string]$colorText = $AccentColor.Trim()
	if ($colorText -match '^(#|0x)?(FF)?(?<hex>[0-9A-Fa-f]{6})$') {
		[string]$hex = $Matches['hex']
		[int[]]$rgb = @(
			[System.Convert]::ToInt32($hex.Substring(0, 2), 16),
			[System.Convert]::ToInt32($hex.Substring(2, 2), 16),
			[System.Convert]::ToInt32($hex.Substring(4, 2), 16)
		)
	}
	elseif ($colorText -match '^(?<red>\d{1,3})(\s*[,;]\s*|\s+)(?<green>\d{1,3})(\s*[,;]\s*|\s+)(?<blue>\d{1,3})$') {
		[int[]]$rgb = @([int]$Matches['red'], [int]$Matches['green'], [int]$Matches['blue'])
		if (@($rgb | Where-Object { $_ -gt 255 }).Count -gt 0) {
			throw "The accent color '$AccentColor' contains a RGB value greater than 255."
		}
	}
	else {
		throw "The accent color '$AccentColor' is neither three RGB values like '227,0,15' nor a hex value like '#E3000F' or '0xFFE3000F' (eight digits only with the opaque alpha channel FF)."
	}

	switch ($PackageFramework) {
		([version]'3.0') {
			[string]$customUiPath = [System.IO.Path]::Combine($PackagePath.FullName, 'AppDeployToolkit', 'CustomAppDeployToolkitUi.ps1')
			if ($false -eq [System.IO.File]::Exists($customUiPath)) {
				throw "The file '$customUiPath' does not exist."
			}

			[byte[]]$customUiBytes = [System.IO.File]::ReadAllBytes($customUiPath)
			[bool]$hasByteOrderMark = $customUiBytes.Length -ge 3 -and $customUiBytes[0] -eq 0xEF -and $customUiBytes[1] -eq 0xBB -and $customUiBytes[2] -eq 0xBF
			[string]$customUi = [System.IO.File]::ReadAllText($customUiPath)
			[regex]$mainColorRegex = '<\s*Color\s+x:Key="MainColor"\s*(?>[RBGA]\s*=\s*"[0-9]{0,3}"\s*){3,4}(?>\s*>\s*<\s*/Color\s*>|\s*/\s*>)'

			if ($false -eq $mainColorRegex.IsMatch($customUi)) {
				Write-Warning -Message "The file '$customUiPath' carries no MainColor resource, the accent color was not set."
				break
			}

			[string]$mainColor = '<Color x:Key="MainColor" A="255" R="{0}" G="{1}" B="{2}" ></Color>' -f $rgb[0], $rgb[1], $rgb[2]
			[string]$updatedCustomUi = $mainColorRegex.Replace($customUi, $mainColor)
			if ($updatedCustomUi -ceq $customUi) {
				Write-Output "The accent color in '$customUiPath' already is $($rgb -join ',')."
				break
			}

			[System.IO.File]::WriteAllText($customUiPath, $updatedCustomUi, [System.Text.UTF8Encoding]::new($hasByteOrderMark))
			Write-Output "The accent color $($rgb -join ',') was written to '$customUiPath'."
			break
		}
		([version]'4.0') {
			if ($false -eq [System.IO.File]::Exists([System.IO.Path]::Combine($PackagePath.FullName, 'Deploy-Application.ps1'))) {
				throw "The directory '$($PackagePath.FullName)' is not the root of a package, it carries no Deploy-Application.ps1."
			}

			[string]$overridesPath = [System.IO.Path]::Combine($PackagePath.FullName, 'Overrides.AccentColor')
			if ([System.IO.Directory]::Exists($overridesPath)) {
				Remove-DirectoryForced -Path $overridesPath
			}
			[string]$configPath = [System.IO.Path]::Combine($overridesPath, 'Config')
			[System.IO.Directory]::CreateDirectory($configPath) | Out-Null

			## The toolkit expects the value as an unquoted ARGB hex literal
			[string]$accentLiteral = '0xFF{0:X2}{1:X2}{2:X2}' -f $rgb[0], $rgb[1], $rgb[2]
			[string]$configContent = "@{`r`n`tUI     = @{`r`n`t`tFluentAccentColor = $accentLiteral`r`n`t}`r`n}`r`n"
			[string]$configFile = [System.IO.Path]::Combine($configPath, 'config.psd1')
			[System.IO.File]::WriteAllText($configFile, $configContent, [System.Text.UTF8Encoding]::new($true))
			Write-Output "The accent color $accentLiteral was written to '$configFile'."
			break
		}
		Default {
			throw "PackageFramework Version $PackageFramework is not supported."
		}
	}
}
catch {
	Write-Error $_.Exception.Message
	exit 1
}
