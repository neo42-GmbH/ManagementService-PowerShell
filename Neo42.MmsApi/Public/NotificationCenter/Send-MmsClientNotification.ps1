function Send-MmsClientNotification {
	<#
	.SYNOPSIS
		Sends a notification to one or more clients.
	.DESCRIPTION
		POST /api/NotificationCenter/Notifications with a PostNotificationRequest
		({ Notification, Targets }).

		Port of Send-MMSClientNotification from
		ManagementService-PowerShell\API\NotificationCenter\NotificationCenter.psm1,
		with the same parameters and defaults, plus two fixes:
			- the icon is only read when -IconPath is given (the original called
			  ReadAllBytes unconditionally and failed without an icon)
			- -PassThru returns the notification id, so the notification can be
			  read back or removed afterwards

		The request runs through ShouldProcess in Invoke-MmsApiRequest, so
		-WhatIf shows the full body without sending anything.

		StartTime and ProcessAction are part of the API model but not exposed
		here; see docs\api-catalog.md and the NotificationMessage definition in
		docs\swagger-v1.json if they are needed.
	.PARAMETER TargetGuid
		Client ids to notify, as delivered by Get-MmsNotificationCenterTarget
		(property ClientIds) or Get-MmsClient (property Id).
	.PARAMETER Message
		First line of the message.
	.PARAMETER Message2
		Optional second line.
	.PARAMETER MessageHeader
		Optional headline.
	.PARAMETER NotificationGroup
		Group the notification is filed under, default 'Default'.
	.PARAMETER IconPath
		Optional icon file. Sent as raw bytes.
	.PARAMETER Sound
		Sound to play, default 'None'.
	.PARAMETER Theme
		Colour theme, default 'OsDefault'.
	.PARAMETER DisplayBehaviour
		What happens after the notification was displayed.
	.PARAMETER HorizontalAlignment
		Screen position, default 'Right'.
	.PARAMETER VerticalAlignment
		Screen position, default 'Bottom'.
	.PARAMETER PresentationBehaviour
		'Wait' queues behind other notifications, 'Ignore' shows immediately.
	.PARAMETER Language
		Language tag of the texts, for example 'en-US' or 'de-DE'.
	.PARAMETER DisplayAsAlarm
		Show as alarm.
	.PARAMETER DisplayAsBanner
		Show as banner.
	.PARAMETER DisplayAsLarge
		Show in large format.
	.PARAMETER DisplayDuration
		How long the notification stays on screen, default 10 seconds.
	.PARAMETER NotificationCenterExpirationTime
		Expiration inside the notification center, at least one hour.
	.PARAMETER HasReadConfirmation
		Ask the user to confirm, default true (same as the original).
	.PARAMETER PassThru
		Returns the id of the created notification.
	.EXAMPLE
		Send-MmsClientNotification -TargetGuid $clientId -Message 'Hello' -WhatIf
	.EXAMPLE
		$id = Send-MmsClientNotification -TargetGuid $targets.ClientIds -Message 'Maintenance tonight' -MessageHeader 'Attention' -Theme Warning -PassThru
	#>
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([guid])]
	param (
		[Parameter()]
		[guid[]]
		$TargetGuid,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Message,

		[Parameter()]
		[string]
		$Message2,

		[Parameter()]
		[string]
		$MessageHeader,

		[Parameter()]
		[string]
		$NotificationGroup = 'Default',

		[Parameter()]
		[ValidateScript({ Test-Path -LiteralPath $_ })]
		[string]
		$IconPath,

		[Parameter()]
		[ValidateSet('None', 'Default', 'IM', 'Mail', 'Reminder', 'SMS',
			'LoopingAlarm', 'LoopingAlarm2', 'LoopingAlarm3', 'LoopingAlarm4', 'LoopingAlarm5',
			'LoopingAlarm6', 'LoopingAlarm7', 'LoopingAlarm8', 'LoopingAlarm9', 'LoopingAlarm10',
			'LoopingCall', 'LoopingCall2', 'LoopingCall3', 'LoopingCall4', 'LoopingCall5',
			'LoopingCall6', 'LoopingCall7', 'LoopingCall8', 'LoopingCall9', 'LoopingCall10')]
		[string]
		$Sound = 'None',

		[Parameter()]
		[ValidateSet('OsDefault', 'Light', 'Dark', 'Warning', 'Error', 'Success')]
		[string]
		$Theme = 'OsDefault',

		[Parameter()]
		[ValidateSet('KeepAfterDisplay', 'DeleteAfterDisplay', 'KeepAfterDisplayWithExpiration')]
		[string]
		$DisplayBehaviour = 'KeepAfterDisplay',

		[Parameter()]
		[ValidateSet('Left', 'Center', 'Right')]
		[string]
		$HorizontalAlignment = 'Right',

		[Parameter()]
		[ValidateSet('Top', 'Center', 'Bottom')]
		[string]
		$VerticalAlignment = 'Bottom',

		[Parameter()]
		[ValidateSet('Ignore', 'Wait')]
		[string]
		$PresentationBehaviour = 'Wait',

		[Parameter()]
		[string]
		$Language = 'en-US',

		[Parameter()]
		[bool]
		$DisplayAsAlarm,

		[Parameter()]
		[bool]
		$DisplayAsBanner,

		[Parameter()]
		[bool]
		$DisplayAsLarge,

		[Parameter()]
		[timespan]
		$DisplayDuration = '00:00:10',

		[Parameter()]
		[ValidateScript({ $_ -ge [timespan]::FromHours(1) })]
		[timespan]
		$NotificationCenterExpirationTime = '1:00:00',

		[Parameter()]
		[bool]
		$HasReadConfirmation = $true,

		[Parameter()]
		[switch]
		$PassThru,

		[Parameter()]
		[object]
		$Session
	)

	# The API takes the numeric enum values, the parameters take the readable names.
	$displayBehaviourValue = @{
		KeepAfterDisplay               = 0
		DeleteAfterDisplay             = 1
		KeepAfterDisplayWithExpiration = 2
	}
	$horizontalAlignmentValue = @{ Left = 0; Center = 1; Right = 2 }
	$verticalAlignmentValue = @{ Top = 0; Center = 1; Bottom = 2 }
	$presentationBehaviourValue = @{ Ignore = 0; Wait = 1 }
	$themeValue = @{ OsDefault = 0; Light = 1; Dark = 2; Warning = 3; Error = 4; Success = 5 }
	$soundValue = @{
		None = 0; Default = 1; IM = 2; Mail = 3; Reminder = 4; SMS = 5
		LoopingAlarm = 6; LoopingAlarm2 = 7; LoopingAlarm3 = 8; LoopingAlarm4 = 9; LoopingAlarm5 = 10
		LoopingAlarm6 = 11; LoopingAlarm7 = 12; LoopingAlarm8 = 13; LoopingAlarm9 = 14; LoopingAlarm10 = 15
		LoopingCall = 16; LoopingCall2 = 18; LoopingCall3 = 19; LoopingCall4 = 20; LoopingCall5 = 21
		LoopingCall6 = 22; LoopingCall7 = 23; LoopingCall8 = 24; LoopingCall9 = 25; LoopingCall10 = 26
	}

	$notificationId = [guid]::NewGuid()

	$targets = @(foreach ($clientId in $TargetGuid) {
			@{
				ClientId       = [string]$clientId
				Id             = [string][guid]::NewGuid()
				NotificationId = [string]$notificationId
			}
		})

	$messageBody = @{
		NotificationGroup   = $NotificationGroup
		DefaultLanguage     = $Language
		HasReadConfirmation = $HasReadConfirmation
		DisplayDuration     = $DisplayDuration.ToString()
		HorizontalAlignment = $horizontalAlignmentValue[$HorizontalAlignment]
		VerticalAlignment   = $verticalAlignmentValue[$VerticalAlignment]
		PresentationBehaviour = $presentationBehaviourValue[$PresentationBehaviour]
		Sound               = $soundValue[$Sound]
		Theme               = $themeValue[$Theme]
		DisplayBehaviour    = @{
			DisplayAsAlarm                   = $DisplayAsAlarm
			DisplayAsBanner                  = $DisplayAsBanner
			DisplayAsLarge                   = $DisplayAsLarge
			NotificationCenterBehaviour      = $displayBehaviourValue[$DisplayBehaviour]
			NotificationCenterExpirationTime = $NotificationCenterExpirationTime.ToString()
		}
		Lines               = @(
			@{
				Language     = $Language
				Order        = 0
				TextWrapping = 0
				Value        = $Message
			}
		)
	}

	if (-not [string]::IsNullOrEmpty($MessageHeader)) {
		$messageBody['Headers'] = @(
			@{
				Language     = $Language
				Order        = 0
				TextWrapping = 0
				Value        = $MessageHeader
			}
		)
	}

	if (-not [string]::IsNullOrEmpty($Message2)) {
		$messageBody['Lines'] += @{
			Language     = $Language
			Order        = 1
			TextWrapping = 1
			Value        = $Message2
		}
	}

	if (-not [string]::IsNullOrWhiteSpace($IconPath)) {
		$messageBody['IconData'] = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $IconPath).ProviderPath)
	}

	$body = @{
		Notification = @{
			Id      = [string]$notificationId
			Message = $messageBody
		}
		Targets      = $targets
	}

	$targetList = @($TargetGuid) -join ', '
	if ([string]::IsNullOrWhiteSpace($targetList)) {
		$targetList = '<no target>'
	}
	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ("client(s) $targetList") -Action ("Send the notification '$Message'"))) {
		return
	}

	$null = Invoke-MmsApiRequest -Path '/api/NotificationCenter/Notifications' -Method POST -Body $body -Session $Session -Confirm:$false

	if ($PassThru) {
		return $notificationId
	}
}
