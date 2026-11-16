function Remove-MmsApcEmpCleanupJob {
	<#
	.SYNOPSIS
		Deletes an Empirum cleanup job.
	.DESCRIPTION
		DELETE /api/apc/EmpirumCleanupJob/{id}

		Removes the job entry. It does not undo a cleanup that already ran.

		The request runs through ShouldProcess in Invoke-MmsApiRequest, so
		-WhatIf shows the call without sending it. Because this deletes server
		side state, ConfirmImpact is High: without -Confirm:$false PowerShell
		asks before the call is made.
	.PARAMETER JobId
		Job to delete.
	.EXAMPLE
		Remove-MmsApcEmpCleanupJob -JobId $jobId -WhatIf
	.EXAMPLE
		Remove-MmsApcEmpCleanupJob -JobId $jobId
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param (
		[Parameter(Mandatory = $true)]
		[guid]
		$JobId,

		[Parameter()]
		[object]
		$Session
	)

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ('Empirum cleanup job {0}' -f $JobId) -Action 'Delete')) {
		return
	}

	return Invoke-MmsApiRequest -Path ('/api/apc/EmpirumCleanupJob/{0}' -f $JobId) -Method DELETE -Session $Session -Confirm:$false -Unwrap
}
