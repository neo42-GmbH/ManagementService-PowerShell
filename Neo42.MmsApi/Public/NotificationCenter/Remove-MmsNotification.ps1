function Remove-MmsNotification {
	<#
	.SYNOPSIS
		Deletes a notification from the Notification Center.
	.DESCRIPTION
		DELETE /api/NotificationCenter/Notifications/{id}

		Removes the notification including its targets. ConfirmImpact is High,
		so PowerShell asks before the request goes out; use -Confirm:$false for
		unattended runs and -WhatIf to see the call only.
	.PARAMETER NotificationGuid
		Notification to delete.
	.EXAMPLE
		Remove-MmsNotification -NotificationGuid $notificationId -WhatIf
	.EXAMPLE
		Get-MmsNotification -ClientId $clientId | ForEach-Object { Remove-MmsNotification -NotificationGuid $_.Notification.Id -Confirm:$false }
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param (
		[Parameter(Mandatory = $true)]
		[Alias('NotificationId')]
		[guid]
		$NotificationGuid,

		[Parameter()]
		[object]
		$Session
	)

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ('Notification {0}' -f $NotificationGuid) -Action 'Delete')) {
		return
	}

	return Invoke-MmsApiRequest -Path ('/api/NotificationCenter/Notifications/{0}' -f $NotificationGuid) -Method DELETE -Session $Session -Confirm:$false
}
