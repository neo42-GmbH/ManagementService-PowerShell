#requires -version 5
<#
.SYNOPSIS
	Stages a clean copy of Neo42.MmsApi for release, without the development files.
.DESCRIPTION
	Publish-Module packs the whole module folder. Run against the working copy it
	would ship the test suite, this script and the contributor notes to the
	PowerShell Gallery, so the artifact is staged first and published from there.

	What goes into the artifact:
		Neo42.MmsApi.psd1  Neo42.MmsApi.psm1
		Public\  Private\  README.md
		docs\              needed at RUNTIME, not documentation: Find-MmsApiRoute
		                   reads swagger-v1.json, and Invoke-MmsApiRequest uses it
		                   to warn about undocumented routes

	What stays behind:
		Tests\             the suite belongs to the repository, not to a consumer
		Tools\             maintenance scripts, this one included
		CONTRIBUTING.md    for people changing the module, not using it

	The staged copy is verified before it is handed over: it has to import on its
	own, without a warning, and export exactly the functions the manifest
	declares. A release that fails that is a release that would fail on a clean
	machine.

	Release on a tag, not on every commit to the default branch. The Gallery
	refuses to replace a version that already exists, so ModuleVersion has to
	increase for every publish - one release per commit burns version numbers
	within a week.

	The script only stages. Publishing stays a deliberate manual step:

		Publish-Module -Path <staged> -NuGetApiKey <key>
.PARAMETER OutputPath
	Directory the versioned folder is created in. A subfolder named after the
	module version is created inside it, which is the layout Publish-Module and
	$env:PSModulePath both expect.
.PARAMETER Force
	Overwrites an already staged folder of the same version.
.PARAMETER Quiet
	Skips the closing summary. Used by Install-MmsApiModule.ps1, which prints its
	own - a hint to publish from a module directory would be misleading there.
.EXAMPLE
	.\Build-MmsApiRelease.ps1 -OutputPath C:\Temp\release -WhatIf
	Shows what would be staged and writes nothing.
.EXAMPLE
	.\Build-MmsApiRelease.ps1 -OutputPath C:\Temp\release
.EXAMPLE
	.\Build-MmsApiRelease.ps1 -OutputPath C:\Temp\release -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param (
	[Parameter(Mandatory = $true)]
	[System.IO.DirectoryInfo]
	$OutputPath,

	[Parameter()]
	[switch]
	$Force,

	[Parameter()]
	[switch]
	$Quiet
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Path $PSScriptRoot -Parent
$manifestPath = Join-Path -Path $moduleRoot -ChildPath 'Neo42.MmsApi.psd1'
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath

$version = $manifest.ModuleVersion
if ([string]::IsNullOrWhiteSpace($version)) {
	throw "The manifest declares no ModuleVersion: $manifestPath"
}

# Named after the version, because that is the layout both Publish-Module and
# $env:PSModulePath expect: <module>\<version>\<module>.psd1
$target = Join-Path -Path (Join-Path -Path $OutputPath.FullName -ChildPath 'Neo42.MmsApi') -ChildPath $version

if (Test-Path -LiteralPath $target) {
	if (-not $Force) {
		# Neutral wording on purpose: Install-MmsApiModule.ps1 surfaces this same
		# message, and there the folder is an installation, not a staging area.
		throw "Version $version already exists at $target. Pass -Force to overwrite, or raise ModuleVersion in the manifest."
	}
	if ($PSCmdlet.ShouldProcess($target, 'Remove the previously staged folder')) {
		Remove-Item -LiteralPath $target -Recurse -Force
	}
}

# Listed rather than derived by exclusion: a new development folder is then left
# out by default instead of shipping because nobody updated a filter.
$include = @(
	'Neo42.MmsApi.psd1'
	'Neo42.MmsApi.psm1'
	'README.md'
	'Public'
	'Private'
	'docs'
)

foreach ($item in $include) {
	$source = Join-Path -Path $moduleRoot -ChildPath $item
	if (-not (Test-Path -LiteralPath $source)) {
		throw "Missing from the working copy, cannot release: $source"
	}
}

if (-not $PSCmdlet.ShouldProcess($target, "Stage Neo42.MmsApi $version")) {
	Write-Host ''
	Write-Host ('Would stage version {0} into:' -f $version)
	Write-Host ('  {0}' -f $target)
	Write-Host ''
	Write-Host 'Would copy:'
	foreach ($item in $include) {
		Write-Host ('  {0}' -f $item)
	}
	Write-Host ''
	Write-Host 'Would leave behind:'
	foreach ($item in @(Get-ChildItem -LiteralPath $moduleRoot | Where-Object { $_.Name -notin $include })) {
		Write-Host ('  {0}' -f $item.Name)
	}
	return
}

New-Item -ItemType Directory -Path $target -Force | Out-Null

foreach ($item in $include) {
	$source = Join-Path -Path $moduleRoot -ChildPath $item
	Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
}

# The artifact has to stand on its own. Importing the copy - not the working
# copy - is the only way to find out, so it runs in a child process: an import
# in this session would be shadowed by an already loaded Neo42.MmsApi, and the
# check would pass on the wrong files.
$stagedManifest = Join-Path -Path $target -ChildPath 'Neo42.MmsApi.psd1'
$verify = @"
`$warnings = @()
Import-Module -Name '$stagedManifest' -Force -WarningVariable warnings -WarningAction SilentlyContinue -ErrorAction Stop
'WARNINGS=' + ((`$warnings | ForEach-Object { `$_.ToString() }) -join ' | ')
'EXPORTED=' + (@((Get-Module -Name 'Neo42.MmsApi').ExportedFunctions.Keys) -join ',')
"@

$output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $verify

$result = @{}
foreach ($line in $output) {
	if ($line -match '^(WARNINGS|EXPORTED)=(.*)$') { $result[$Matches[1]] = $Matches[2] }
}

if (-not [string]::IsNullOrWhiteSpace($result['WARNINGS'])) {
	throw "The staged copy warns on import, which a released module must not do: $($result['WARNINGS'])"
}

$exported = @($result['EXPORTED'] -split ',' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$declared = @($manifest.FunctionsToExport)
$missing = @($declared | Where-Object { $_ -notin $exported })

if ($missing.Count -gt 0) {
	throw "The staged copy does not export everything the manifest declares: $($missing -join ', ')"
}

if ($Quiet) {
	return
}

Write-Host ''
Write-Host ('Staged Neo42.MmsApi {0}' -f $version) -ForegroundColor Green
Write-Host ('  {0}' -f $target)
Write-Host ('  {0} functions, {1:n0} KB' -f
	$exported.Count,
	((Get-ChildItem -LiteralPath $target -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1KB))
Write-Host ''
Write-Host 'Publish with:' -ForegroundColor Cyan
Write-Host ('  Publish-Module -Path "{0}" -NuGetApiKey <key>' -f $target)
