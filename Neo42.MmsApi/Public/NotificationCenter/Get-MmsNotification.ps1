function Get-MmsNotification {
	<#
	.SYNOPSIS
		Returns notifications from the Notification Center.
	.DESCRIPTION
		GET /api/NotificationCenter/Notifications/All   all notifications
		GET /api/NotificationCenter/Notifications/{id}  one notification

		Both routes answer with NotificationWithTargets, so an item carries its
		Notification and its Targets.

		-ClientId filters client side over /All, on purpose: the server side
		route /api/NotificationCenter/Notifications/Client returns plain
		Notification objects without targets, and the example scripts rely on
		the shape with targets ($_.Notification.Id).
	.PARAMETER NotificationGuid
		Single notification by id.
	.PARAMETER ClientId
		Only notifications that target this client.
	.EXAMPLE
		Get-MmsNotification
	.EXAMPLE
		Get-MmsNotification -ClientId $clientId
	.EXAMPLE
		Get-MmsNotification -NotificationGuid $notificationId
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true)]
		[Alias('NotificationId')]
		[guid]
		$NotificationGuid,

		[Parameter(ParameterSetName = 'All')]
		[string]
		$ClientId,

		[Parameter()]
		[object]
		$Session
	)

	if ($PSCmdlet.ParameterSetName -eq 'ById') {
		return Invoke-MmsApiRequest -Path ('/api/NotificationCenter/Notifications/{0}' -f $NotificationGuid) -Session $Session
	}

	$notifications = Invoke-MmsApiRequest -Path '/api/NotificationCenter/Notifications/All' -Session $Session

	if ([string]::IsNullOrWhiteSpace($ClientId)) {
		return $notifications
	}

	return $notifications | Where-Object { $_.Targets.ClientId -contains $ClientId }
}
