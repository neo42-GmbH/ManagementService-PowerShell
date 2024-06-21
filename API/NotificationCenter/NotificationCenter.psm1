#requires -Version 5.0
<#
.SYNOPSIS
	This Module allows to get, send and delete Notifications via neo42 Management Service, utilizing the API.
#>
function Get-MMSNotificationCenterTargets {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$ServerName
	)
	if ( $ServerName -notlike "https://*" ) {
		$ServerName = "https://$ServerName"
	}
	$targetsUrl = "$ServerName/api/NotificationCenter/Target/All"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("X-Neo42-Auth", "Admin")
	$targets = Invoke-RestMethod -Method Get -Uri $targetsUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
	return $targets
}
function Send-MMSClientNotification {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$ServerName,
		[Parameter(Mandatory = $false)]
		[GUID[]]
		$TargetGuid,
		[Parameter(Mandatory = $true)]
		[string]
		$Message,
		[Parameter(Mandatory = $false)]
		[string]
		$Message2,
		[Parameter(Mandatory = $false)]
		[string]
		$MessageHeader,
		[Parameter(Mandatory = $false)]
		[string]
		$NotificationGroup = "Default",
		[Parameter(Mandatory = $false)]
		[ValidateScript({Test-Path $_})]
		[string]
		$IconPath,
		[Parameter(Mandatory = $false)]
		[string]
		[ValidateSet("None", "Default", "IM", "Mail", "Reminder", "SMS", "LoopingAlarm", "LoopingAlarm2", "LoopingAlarm3", "LoopingAlarm4", "LoopingAlarm5", "LoopingAlarm6", "LoopingAlarm7", "LoopingAlarm8", "LoopingAlarm9", "LoopingAlarm10", "LoopingCall", "LoopingCall2", "LoopingCall3", "LoopingCall4", "LoopingCall5", "LoopingCall6", "LoopingCall7", "LoopingCall8", "LoopingCall9", "LoopingCall10")]
		$Sound = "None",
		[Parameter(Mandatory = $false)]
		[string]
		[ValidateSet("OsDefault", "Light", "Dark", "Warning", "Error", "Success")]
		$Theme = "OsDefault",
		[Parameter(Mandatory = $false)]
		[string]
		[ValidateSet("KeepAfterDisplay", "DeleteAfterDisplay", "KeepAfterDisplayWithExpiration")]
		$DisplayBehaviour = "KeepAfterDisplay",
		[Parameter(Mandatory = $false)]
		[ValidateSet("Left", "Center", "Right")]
		[string]
		$HorizontalAlignment = "Right",
		[Parameter(Mandatory = $false)]
		[string]
		[ValidateSet("Top", "Center", "Bottom")]
		$VerticalAlignment = "Bottom",
		[Parameter(Mandatory = $false)]
		[string]
		[ValidateSet("Ignore", "Wait")]
		$PresentationBehaviour = "Wait",
		[Parameter(Mandatory = $false)]
		# en-US, de-DE, fr-FR, es-ES, it-IT
		[string]
		$Language = "en-US",
		[Parameter(Mandatory = $false)]
		[bool]
		$DisplayAsAlarm,
		[Parameter(Mandatory = $false)]
		[bool]
		$DisplayAsBanner,
		[Parameter(Mandatory = $false)]
		[bool]
		$DisplayAsLarge,
		[Parameter(Mandatory = $false)]
		[timespan]
		$DisplayDuration = "00:00:10",
		[Parameter(Mandatory = $false)]
		[timespan]
		[ValidateScript({$_ -ge [timespan]::FromHours(1)})]
		$NotificationCenterExpirationTime = "1:00:00"
	)
	## Hash Tables for Enums
	$displayBehaviourEnum = @{
		KeepAfterDisplay = 0
		DeleteAfterDisplay = 1
		KeepAfterDisplayWithExpiration = 2
	}
	$horizontalAlignmentEnum = @{
		Left = 0
		Center = 1
		Right = 2
	}
	$verticalAlignmentEnum = @{
		Top = 0
		Center = 1
		Bottom = 2
	}
	$presentationBehaviourEnum = @{
		Ignore = 0
		Wait = 1
	}
	$soundEnum = @{
		None = 0
		Default = 1
		IM = 2
		Mail = 3
		Reminder = 4
		SMS = 5
		LoopingAlarm = 6
		LoopingAlarm2 = 7
		LoopingAlarm3 = 8
		LoopingAlarm4 = 9
		LoopingAlarm5 = 10
		LoopingAlarm6 = 11
		LoopingAlarm7 = 12
		LoopingAlarm8 = 13
		LoopingAlarm9 = 14
		LoopingAlarm10 = 15
		LoopingCall = 16
		LoopingCall2 = 18
		LoopingCall3 = 19
		LoopingCall4 = 20
		LoopingCall5 = 21
		LoopingCall6 = 22
		LoopingCall7 = 23
		LoopingCall8 = 24
		LoopingCall9 = 25
		LoopingCall10 = 26
	}
	$themeEnum = @{
		OsDefault = 0
		Light = 1
		Dark = 2
		Warning = 3
		Error = 4
		Success = 5
	}
	## Create Notification
	if ( $ServerName -notlike "https://*" ) {
		$ServerName = "https://$ServerName"
	}
	$notificationsUrl = "$ServerName/api/NotificationCenter/Notifications"

	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("X-Neo42-Auth", "Admin")
	$headers.Add("Content-Type", "application/json")

	$notificationId = (New-Guid).Guid
	[array]$targets = $TargetGuid | ForEach-Object {
		@{
			ClientId = "$_" # Required
			Id = (New-Guid).Guid # Required
			NotificationId = $notificationId # Required
		}
	}
	$notification = @{
		Notification = @{
			Id = $notificationId # Required
			Message = @{
				NotificationGroup = $NotificationGroup # Required
				DefaultLanguage = $Language # Required
				DisplayBehaviour = @{ # Required
					DisplayAsAlarm =  $DisplayAsAlarm # Optional
					DisplayAsBanner = $DisplayAsBanner # Optional
					DisplayAsLarge = $DisplayAsLarge # Optional
					NotificationCenterBehaviour = $displayBehaviourEnum.$DisplayBehaviour # Required
					NotificationCenterExpirationTime = $NotificationCenterExpirationTime.ToString() # Required, when displayBehaviour.KeepAfterDisplayWithExpiration, min. 1h
				}
				DisplayDuration = $DisplayDuration.ToString() # Optional
				HasReadConfirmation = $true # Optional
				HorizontalAlignment = $horizontalAlignmentEnum.$HorizontalAlignment # Optional
				PresentationBehaviour = $presentationBehaviourEnum.$PresentationBehaviour # Optional
				Sound = $soundEnum.$Sound # Optional
				Theme =  $themeEnum.$Theme # Optinal
				VerticalAlignment = $verticalAlignmentEnum.$VerticalAlignment # Optional
				Lines = @( # Required
					@{
						Language = $Language # Required
						Order = 0 # Required
						TextWrapping = 0 # Required
						Value = $Message # Required
					}
				)
				IconData = [System.IO.File]::ReadAllBytes($IconPath) # Optional
				<#
				StartTime = Get-Date -Format $isoTimeFormat -Date (Get-Date).AddSeconds(10) # Optional
				
				CreationDate = Get-Date -Format $isoTimeFormat # Optional
				ProcessAction = @{ # Optional
					Arguments = "/c echo 'Hello World'" # Optional
					ProcessPath = "cmd.exe" # Required
				}
				#>
			}
		}
		Targets = $targets
	}
	if ( $false -eq [string]::IsNullOrEmpty($MessageHeader)) {
		$notification.Notification.Message["Headers"] = @(
			@{
				Language = $Language # Required
				Order = 0 # Required
				TextWrapping = 0 # Required
				Value = $MessageHeader # Required
			}
		)
	}
	if ( $false -eq [string]::IsNullOrEmpty($Message2)) {
		$notification.Notification.Message["Lines"] += @{
			Language = $Language # Required
			Order = 1 # Required
			TextWrapping = 1 # Required
			Value = $Message2 # Required
		}
	}
	Invoke-WebRequest -Method Post -Uri $notificationsUrl -Headers $headers -Body ($notification | ConvertTo-Json -Depth 10) -UseDefaultCredentials | Out-Null
}
function Get-MMSNotification {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$ServerName,
		[Parameter(Mandatory = $false)]
		[guid]
		$NotificationGuid,
		[Parameter(Mandatory = $false)]
		[string]
		$ClientID
	)
	if ( $ServerName -notlike "https://*" ) {
		$ServerName = "https://$ServerName"
	}
	if ( [string]::IsNullOrEmpty($NotificationGuid) ) {
		$notificationsUrl = "$ServerName/api/NotificationCenter/Notifications/All"
	} else {
		$notificationsUrl = "$ServerName/api/NotificationCenter/Notifications/$NotificationGuid"
	}
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("X-Neo42-Auth", "Admin")
	$notifications = Invoke-RestMethod -Method Get -Uri $notificationsUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
	if ( [string]::IsNullOrEmpty($ClientID) ) {
		return $notifications
	}
	else {
		return $notifications | Where-Object { $_.Targets.ClientId -contains $ClientID }
	}
}
function Remove-MMSNotification {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$ServerName,
		[Parameter(Mandatory = $true)]
		[guid]
		$NotificationGuid
	)
	if ( $ServerName -notlike "https://*" ) {
		$ServerName = "https://$ServerName"
	}
	$notificationsUrl = "$ServerName/api/NotificationCenter/Notifications/$NotificationGuid"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("X-Neo42-Auth", "Admin")
	Invoke-RestMethod -Method Delete -Uri $notificationsUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop
}

function Remove-MMSPendingNotifications {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$ServerName
	)
	if ( $ServerName -notlike "https://*" ) {
		$ServerName = "https://$ServerName"
	}
	$Url = "$ServerName/NotificationCenter/NotificationTarget/Pending"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("X-Neo42-Auth", "Admin")
	Invoke-RestMethod -Method Delete -Uri $Url -Headers $headers -UseDefaultCredentials -ErrorAction Stop
}