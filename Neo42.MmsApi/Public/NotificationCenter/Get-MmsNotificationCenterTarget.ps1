function Get-MmsNotificationCenterTarget {
	<#
	.SYNOPSIS
		Returns the notification targets known to the Notification Center.
	.DESCRIPTION
		GET /api/NotificationCenter/Target/All

		A target groups client ids under a name (client, group or user), so the
		usual pattern is to pick targets by name and pass their ClientIds to
		Send-MmsClientNotification.

		Name and behaviour match the function of the same name in
		ManagementService-PowerShell\API\NotificationCenter\NotificationCenter.psm1.
	.EXAMPLE
		Get-MmsNotificationCenterTarget | Format-Table Name, Type, ClientIds
	.EXAMPLE
		$targets = Get-MmsNotificationCenterTarget | Where-Object { $_.Name -in $TargetNames }
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter()]
		[object]
		$Session
	)

	return Invoke-MmsApiRequest -Path '/api/NotificationCenter/Target/All' -Session $Session
}
