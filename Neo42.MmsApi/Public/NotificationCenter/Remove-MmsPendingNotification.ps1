function Remove-MmsPendingNotification {
	<#
	.SYNOPSIS
		Deletes all pending notification targets.
	.DESCRIPTION
		DELETE /api/NotificationCenter/NotificationTarget/Pending

		Affects every notification that has not been delivered yet, not just one
		client - hence ConfirmImpact High. Use -Confirm:$false for unattended
		runs and -WhatIf to see the call only.

		Note: the example module in ManagementService-PowerShell builds this url
		without the '/api' prefix, which cannot work against the documented
		route. This function uses the documented path.
	.EXAMPLE
		Remove-MmsPendingNotification -WhatIf
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param (
		[Parameter()]
		[object]
		$Session
	)

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target 'All pending notification targets' -Action 'Delete')) {
		return
	}

	return Invoke-MmsApiRequest -Path '/api/NotificationCenter/NotificationTarget/Pending' -Method DELETE -Session $Session -Confirm:$false
}
