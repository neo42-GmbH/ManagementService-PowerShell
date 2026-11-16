function Get-MmsSwaggerDocument {
	<#
	.SYNOPSIS
		Loads the cached swagger document that ships next to the module.
	.DESCRIPTION
		docs\swagger-v1.json is the snapshot of the documented ("released") API
		surface, refreshed by Tools\Update-MmsApiCatalog.ps1. It is parsed once
		per session and then kept in memory, because the document is large.
	#>
	[CmdletBinding()]
	param (
		[Parameter()]
		[switch]
		$Force
	)

	if ($null -ne $script:MmsSwaggerDocument -and -not $Force) {
		return $script:MmsSwaggerDocument
	}

	$path = Join-Path -Path $script:MmsModuleRoot -ChildPath 'docs\swagger-v1.json'
	if (-not (Test-Path -LiteralPath $path)) {
		throw ("No swagger snapshot found at '$path'. Refresh it with " +
			"Tools\Update-MmsApiCatalog.ps1 (requires 'EnableApiDocumentation' to be active on the server).")
	}

	$script:MmsSwaggerDocument = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
	return $script:MmsSwaggerDocument
}
