function Start-MmsApcPackageSync {
	<#
	.SYNOPSIS
		Starts a package synchronisation of the APC.
	.DESCRIPTION
		POST /api/apc/PackageInteraction/StartSync

		Triggers the sync of the package list with the neo42 package depot and
		returns true when it was accepted. Progress is visible through
		Get-MmsApcPackageSyncJob.

		Takes server side load, so ConfirmImpact is High. Use -WhatIf to see the
		call and -Confirm:$false for unattended runs.
	.EXAMPLE
		Start-MmsApcPackageSync -WhatIf
	.EXAMPLE
		Start-MmsApcPackageSync -Confirm:$false
		Get-MmsApcPackageSyncJob
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	[OutputType([bool])]
	param (
		[Parameter()]
		[object]
		$Session
	)

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target 'Application Package Center' -Action 'Start package synchronisation')) {
		return
	}

	return Invoke-MmsApiRequest -Path '/api/apc/PackageInteraction/StartSync' -Method POST -Session $Session -Confirm:$false -Unwrap
}
