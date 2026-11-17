#requires -version 5
<#
.SYNOPSIS
	Installs Neo42.MmsApi into a PowerShell module directory.
.DESCRIPTION
	Makes the module available in every session, so 'Import-Module Neo42.MmsApi'
	works from anywhere and the example scripts under ..\..\API\ stop falling back
	to the copy in the repository.

	What is installed is the release artifact, not the working copy: the staging
	and the include list live in Build-MmsApiRelease.ps1 and this script calls
	it. That is deliberate - two copies of 'which folders ship' drift apart, and
	the one that gets forgotten is the one that ships the test suite.

	Installed into <module directory>\Neo42.MmsApi\<version>\, the layout
	PowerShell expects for a versioned module. An older version already there is
	left alone unless it carries the same version number, so a rollback is a
	matter of removing one folder.

	Uninstall by deleting that folder:

		Remove-Item "$HOME\Documents\WindowsPowerShell\Modules\Neo42.MmsApi" -Recurse
.PARAMETER Scope
	CurrentUser installs into the Documents module path and needs no elevation.
	AllUsers installs into the machine wide path and requires an elevated
	session. Default CurrentUser.
.PARAMETER Force
	Overwrites an installation of the same version.
.EXAMPLE
	.\Install-MmsApiModule.ps1 -WhatIf
	Shows where it would install and what would be copied.
.EXAMPLE
	.\Install-MmsApiModule.ps1
.EXAMPLE
	.\Install-MmsApiModule.ps1 -Scope AllUsers
	Needs an elevated session.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
	[Parameter()]
	[ValidateSet('CurrentUser', 'AllUsers')]
	[string]
	$Scope = 'CurrentUser',

	[Parameter()]
	[switch]
	$Force
)

$ErrorActionPreference = 'Stop'

# Built from the documented WindowsPowerShell locations rather than by picking an
# entry out of $env:PSModulePath: that variable also carries the module paths of
# other hosts and of PowerShell 7, and installing into one of those would put the
# module somewhere the 5.1 session under test never looks.
$moduleDirectory = if ($Scope -eq 'AllUsers') {
	Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules'
}
else {
	Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules'
}

if ($Scope -eq 'AllUsers') {
	$identity = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
	if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		throw "-Scope AllUsers writes to '$moduleDirectory' and needs an elevated session. Use -Scope CurrentUser instead."
	}
}

# Warn rather than fail: the path is created below and picked up by the next
# session, so an unusual PSModulePath is worth saying out loud but not a reason
# to refuse.
if (($env:PSModulePath -split ';') -notcontains $moduleDirectory) {
	Write-Warning "Not currently listed in `$env:PSModulePath: $moduleDirectory"
	Write-Warning 'Import-Module Neo42.MmsApi may only work after the next session starts.'
}

if (-not (Test-Path -LiteralPath $moduleDirectory)) {
	if ($PSCmdlet.ShouldProcess($moduleDirectory, 'Create the module directory')) {
		New-Item -ItemType Directory -Path $moduleDirectory -Force | Out-Null
	}
}

# -WhatIf and -Force pass straight through, so the preview and the overwrite
# behaviour are the ones of the staging script and cannot disagree with it.
$build = Join-Path -Path $PSScriptRoot -ChildPath 'Build-MmsApiRelease.ps1'
& $build -OutputPath $moduleDirectory -Force:$Force -Quiet:(-not $WhatIfPreference) -WhatIf:$WhatIfPreference

if ($WhatIfPreference) {
	return
}

$manifest = Import-PowerShellDataFile -LiteralPath (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Neo42.MmsApi.psd1')

Write-Host ''
Write-Host ('Installed for {0}.' -f $Scope) -ForegroundColor Green
Write-Host ''
Write-Host 'Check it in a NEW session:' -ForegroundColor Cyan
Write-Host '  Get-Module -ListAvailable Neo42.MmsApi'
Write-Host '  Import-Module Neo42.MmsApi'
Write-Host ("  Connect-MmsApi -ServerName 'https://server.domain:4242'")
Write-Host ''
Write-Host ('Remove it again with:')
Write-Host ('  Remove-Item "{0}" -Recurse' -f (Join-Path -Path $moduleDirectory -ChildPath 'Neo42.MmsApi'))
Write-Host ''
Write-Host ('Version {0}' -f $manifest.ModuleVersion) -ForegroundColor DarkGray
