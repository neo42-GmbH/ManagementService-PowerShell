function Test-MmsApcEmpCleanupDuplicates {
	<#
	.SYNOPSIS
		Checks a list of Empirum packages for duplicates.
	.DESCRIPTION
		POST /api/apc/EmpirumCleanup/CheckForDuplicates
		with { TenantId, EmpirumCleanupItems, JobId }

		A POST, but it only evaluates and returns the duplicates it found. Run it
		before Start-MmsApcEmpCleanupJob and pass the outcome on via
		-DuplicatesFound.

		Because the route is a POST it goes through ShouldProcess: with -WhatIf
		the check is not sent and nothing is returned.
	.PARAMETER TenantId
		Tenant the packages belong to.
	.PARAMETER EmpirumCleanupItems
		Items to check, as returned by Get-MmsApcEmpCleanupPackageList.
	.PARAMETER JobId
		Existing job the check belongs to.
	.EXAMPLE
		$duplicates = Test-MmsApcEmpCleanupDuplicates -TenantId $tenantId -EmpirumCleanupItems $packages -JobId $jobId
	#>
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[guid]
		$TenantId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[object[]]
		$EmpirumCleanupItems,

		[Parameter(Mandatory = $true)]
		[guid]
		$JobId,

		[Parameter()]
		[object]
		$Session
	)

	$body = @{
		TenantId            = [string]$TenantId
		EmpirumCleanupItems = @($EmpirumCleanupItems)
		JobId               = [string]$JobId
	}

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ("job $JobId") -Action ("Check $(@($EmpirumCleanupItems).Count) package(s) for duplicates"))) {
		return
	}

	return Invoke-MmsApiRequest -Path '/api/apc/EmpirumCleanup/CheckForDuplicates' -Method POST -Body $body -Session $Session -Unwrap -Confirm:$false
}
