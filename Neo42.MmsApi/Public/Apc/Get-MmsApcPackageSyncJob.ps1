function Get-MmsApcPackageSyncJob {
	<#
	.SYNOPSIS
		Returns the latest package synchronisation job.
	.DESCRIPTION
		GET /api/apc/PackageInteraction/LatestSyncJob

		Shows when the APC last synchronised its package list with the neo42
		package depot, and how that run ended. Start-MmsApcPackageSync triggers a
		new one.
	.EXAMPLE
		Get-MmsApcPackageSyncJob | Format-List
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter()]
		[object]
		$Session
	)

	return Invoke-MmsApiRequest -Path '/api/apc/PackageInteraction/LatestSyncJob' -Session $Session -Unwrap
}
