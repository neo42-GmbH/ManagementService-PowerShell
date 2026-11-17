function New-MmsApcEmpCleanupJob {
	<#
	.SYNOPSIS
		Creates an Empirum cleanup job and returns its id.
	.DESCRIPTION
		POST /api/apc/EmpirumCleanupJob with { TenantId, CleanupAction }

		Creating a job does not delete anything: it only opens the job. The
		packages are only touched once Start-MmsApcEmpCleanupJob is called.

		The request itself runs through ShouldProcess in Invoke-MmsApiRequest,
		so -WhatIf shows the exact call including the body without sending it.
	.PARAMETER TenantId
		Tenant the job belongs to.
	.PARAMETER CleanupAction
		NoAssignmentInstallApproved, NoAssignmentNoInstallApproved or AllPackages.
	.EXAMPLE
		New-MmsApcEmpCleanupJob -TenantId $tenantId -CleanupAction AllPackages -WhatIf
	.EXAMPLE
		$jobId = New-MmsApcEmpCleanupJob -TenantId $tenantId -CleanupAction NoAssignmentNoInstallApproved
	#>
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([guid])]
	param (
		[Parameter(Mandatory = $true)]
		[guid]
		$TenantId,

		[Parameter(Mandatory = $true)]
		[ValidateSet('NoAssignmentInstallApproved', 'NoAssignmentNoInstallApproved', 'AllPackages')]
		[string]
		$CleanupAction,

		[Parameter()]
		[object]
		$Session
	)

	$body = @{
		TenantId      = [string]$TenantId
		CleanupAction = (ConvertTo-MmsCleanupActionValue -Action $CleanupAction)
	}

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ("tenant $TenantId") -Action ("Create an Empirum cleanup job for '$CleanupAction'"))) {
		return
	}

	return Invoke-MmsApiRequest -Path '/api/apc/EmpirumCleanupJob' -Method POST -Body $body -Session $Session -Unwrap -Confirm:$false
}
