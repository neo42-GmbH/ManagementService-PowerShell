function Get-MmsApiSnapshotMeta {
	<#
	.SYNOPSIS
		Returns metadata about the local swagger snapshot (or $null if absent).
	.DESCRIPTION
		Written by Tools\Update-MmsApiCatalog.ps1. Holds the server version and
		the date the snapshot was taken, so a stale catalog can be detected.
	#>
	[CmdletBinding()]
	param ()

	$path = Join-Path -Path $script:MmsModuleRoot -ChildPath 'docs\swagger-v1.meta.json'
	if (-not (Test-Path -LiteralPath $path)) {
		return $null
	}

	try {
		return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
	}
	catch {
		Write-Verbose "Could not read the snapshot metadata: $($_.Exception.Message)"
		return $null
	}
}
