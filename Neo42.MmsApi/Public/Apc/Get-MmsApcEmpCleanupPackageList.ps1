function Get-MmsApcEmpCleanupPackageList {
	<#
	.SYNOPSIS
		Returns the Empirum packages that a cleanup action would cover.
	.DESCRIPTION
		GET /api/apc/EmpirumCleanup/CleanupItems?cleanupAction=<n>&tenantId=<guid>

		Read only: the call reports candidates, it changes nothing. The returned
		items are the input for Test-MmsApcEmpCleanupDuplicates and
		Start-MmsApcEmpCleanupJob.
	.PARAMETER Action
		Which candidates to list:
			NoAssignmentInstallApproved    (1) no assignment, install approved
			NoAssignmentNoInstallApproved  (2) no assignment, no install approval
			AllPackages                    (3) all packages
	.PARAMETER TenantId
		Tenant the packages belong to.
	.EXAMPLE
		Get-MmsApcEmpCleanupPackageList -Action NoAssignmentNoInstallApproved -TenantId $tenantId
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('NoAssignmentInstallApproved', 'NoAssignmentNoInstallApproved', 'AllPackages')]
		[string]
		$Action,

		[Parameter(Mandatory = $true)]
		[guid]
		$TenantId,

		[Parameter()]
		[object]
		$Session
	)

	$query = @{
		cleanupAction = (ConvertTo-MmsCleanupActionValue -Action $Action)
		tenantId      = $TenantId
	}

	return Invoke-MmsApiRequest -Path '/api/apc/EmpirumCleanup/CleanupItems' -Query $query -Session $Session -Unwrap
}
