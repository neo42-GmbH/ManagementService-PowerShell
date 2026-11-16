#requires -version 5
<#
	Neo42.MmsApi - loader.

	Dot-sources every function file so that adding an endpoint means adding one
	file under Public\<Area>\ (and listing it in Neo42.MmsApi.psd1 ->
	FunctionsToExport). The subfolders under Public\ mirror the MMS plug-ins and
	exist for orientation only: everything is loaded into one module so that all
	functions share the session created by Connect-MmsApi.

	Keep all *.ps1 / *.psm1 / *.psd1 files in this module UTF-8 with BOM and
	CRLF. The BOM is not cosmetic: PowerShell 5.1 reads UTF-8 without one as
	ANSI and mangles every umlaut in the help. Tests\Unit\Module.Hygiene.Tests.ps1
	checks it.
#>

$script:MmsModuleRoot = $PSScriptRoot

foreach ($folder in 'Private', 'Public') {
	$path = Join-Path -Path $PSScriptRoot -ChildPath $folder
	if (-not (Test-Path -LiteralPath $path)) {
		continue
	}
	foreach ($file in Get-ChildItem -LiteralPath $path -Filter '*.ps1' -File -Recurse | Sort-Object -Property FullName) {
		. $file.FullName
	}
}

# Session state set by Connect-MmsApi, used as default by every request.
$script:MmsSession = $null

$publicRoot = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$publicFunctions = @((Get-ChildItem -LiteralPath $publicRoot -Filter '*.ps1' -File -Recurse).BaseName)

# The manifest and the Public folder are two lists that have to agree. Warn on
# drift, so a newly added function is not silently missing after an import.
$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'Neo42.MmsApi.psd1'
if (Test-Path -LiteralPath $manifestPath) {
	$declared = @((Import-PowerShellDataFile -LiteralPath $manifestPath).FunctionsToExport)
	$missing = @($publicFunctions | Where-Object { $_ -notin $declared })
	if ($missing.Count -gt 0) {
		Write-Warning "Neo42.MmsApi: not listed in FunctionsToExport of the manifest: $($missing -join ', ')"
	}
	$orphaned = @($declared | Where-Object { $_ -notin $publicFunctions })
	if ($orphaned.Count -gt 0) {
		Write-Warning "Neo42.MmsApi: listed in the manifest but no file in Public\: $($orphaned -join ', ')"
	}
}

Export-ModuleMember -Function $publicFunctions
