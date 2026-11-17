function Start-MmsApcEmpCleanupJob {
	<#
	.SYNOPSIS
		Starts an Empirum cleanup job with the selected packages.
	.DESCRIPTION
		POST /api/apc/EmpirumCleanup/StartEmpirumCleanupJob
		with { JobId, EmpirumCleanupItems, DuplicatesFound }

		This is the call that actually deletes packages. Everything before it
		(New-MmsApcEmpCleanupJob, Get-MmsApcEmpCleanupPackageList,
		Test-MmsApcEmpCleanupDuplicates) is preparation and reversible.

		ConfirmImpact is High, so PowerShell asks before the request goes out.
		Run it with -WhatIf first and check the item count.
	.PARAMETER JobId
		Job created with New-MmsApcEmpCleanupJob.
	.PARAMETER EmpirumCleanupItems
		The items to clean up, as returned by Get-MmsApcEmpCleanupPackageList.
		Reduce this list to the packages that really should go.
	.PARAMETER DuplicatesFound
		Set when Test-MmsApcEmpCleanupDuplicates reported duplicates.
	.EXAMPLE
		Start-MmsApcEmpCleanupJob -JobId $jobId -EmpirumCleanupItems $selected -WhatIf
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param (
		[Parameter(Mandatory = $true)]
		[guid]
		$JobId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[object[]]
		$EmpirumCleanupItems,

		[Parameter()]
		[bool]
		$DuplicatesFound = $false,

		[Parameter()]
		[object]
		$Session
	)

	$itemCount = @($EmpirumCleanupItems).Count
	$action = 'Start cleanup and delete {0} package(s)' -f $itemCount

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ('Empirum cleanup job {0}' -f $JobId) -Action $action)) {
		return
	}

	$body = @{
		JobId               = [string]$JobId
		EmpirumCleanupItems = @($EmpirumCleanupItems)
		DuplicatesFound     = $DuplicatesFound
	}

	return Invoke-MmsApiRequest -Path '/api/apc/EmpirumCleanup/StartEmpirumCleanupJob' -Method POST -Body $body -Session $Session -Confirm:$false -Unwrap
}
