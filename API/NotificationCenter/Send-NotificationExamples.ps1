<#
	.SYNOPSIS
		Example Script for the Management Service NotificationCenter Module
	.DESCRIPTION
		This Script demonstrates the different possibilities of the NotificationCenter Module.
		You can send Notifications to different Targets with different Themes, Sounds, DisplayBehaviours, Alignments and DisplayDurations.
		You can also send Banner Notifications and Notifications with maximum attention.
		For the Demo Sequence, the Notification will be displayed for 5 to 15 seconds.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[string[]]
	$TargetNames,
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName
)
$PSDefaultParameterValues["*-MMS*:ServerName"] = $ServerName
import-Module -Force $PSScriptRoot\NotificationCenter.psm1
$targets = Get-MMSNotificationCenterTargets | Where-Object {$_.Name -in $TargetNames }
$iconPath = "$PSScriptRoot\Icon.png"


#Demo Sequence for different Possibilities
Read-Host "This will start the demo sequence of different Notifications for the Targets $($targets.Name). Press Enter to continue or CTRL+C to abort."
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "hi, I am a Default Message" -IconPath $iconPath
Start-Sleep 2
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "I can be displayed in 9 different Positions" -IconPath $iconPath -VerticalAlignment Center -HorizontalAlignment Center -DisplayDuration "00:00:05"
Start-Sleep 5
$VerticalAlignments = @("Top", "Center", "Bottom")
$HorizontalAlignments = @("Left", "Center", "Right")
foreach ($VerticalAlignment in $VerticalAlignments) {
	foreach ($HorizontalAlignment in $HorizontalAlignments) {
		Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "I am aligned $VerticalAlignment $HorizontalAlignment" -IconPath $iconPath -VerticalAlignment $VerticalAlignment -HorizontalAlignment $HorizontalAlignment -DisplayDuration "00:00:01"
	}
}
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "Warning Theme with Notification Sound" -IconPath $iconPath -NotificationGroup "Demo" -Sound "LoopingAlarm" -Theme "Warning" -DisplayBehaviour "DeleteAfterDisplay" -HorizontalAlignment "Center" -VerticalAlignment "Center" -PresentationBehaviour "Ignore" -DisplayDuration "00:00:05"
Start-Sleep 5
#Dark Theme
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "Dark Theme" -IconPath $iconPath -NotificationGroup "Demo" -Theme "Dark" -DisplayBehaviour "DeleteAfterDisplay" -HorizontalAlignment "Center" -VerticalAlignment "Center" -PresentationBehaviour "Ignore" -DisplayDuration "00:00:05"
Start-Sleep 5
#light Theme
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "Light Theme" -IconPath $iconPath -NotificationGroup "Demo" -Theme "Light" -DisplayBehaviour "DeleteAfterDisplay" -HorizontalAlignment "Center" -VerticalAlignment "Center" -PresentationBehaviour "Ignore" -DisplayDuration "00:00:05"
#Error Theme
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "Error Theme" -IconPath $iconPath -NotificationGroup "Demo" -Theme "Error" -DisplayBehaviour "DeleteAfterDisplay" -HorizontalAlignment "Center" -VerticalAlignment "Center" -PresentationBehaviour "Ignore" -DisplayDuration "00:00:05"
Start-Sleep 5
#Banner Notification
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "Banner Notification" -IconPath $iconPath -NotificationGroup "Demo" -Theme "Light" -DisplayBehaviour "DeleteAfterDisplay" -VerticalAlignment "Top" -PresentationBehaviour "Ignore" -DisplayDuration "00:00:10" -DisplayAsBanner $true
Start-Sleep 10
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "Banner Notification Mid" -IconPath $iconPath -NotificationGroup "Demo" -Theme "Dark" -DisplayBehaviour "DeleteAfterDisplay" -VerticalAlignment Center -PresentationBehaviour "Ignore" -DisplayDuration "00:00:15" -DisplayAsBanner $true
Start-Sleep 10
#maximum attention Notification
Send-MMSClientNotification -TargetGuid $targets.ClientIds -Message "Maximum Attention Notification" -IconPath $iconPath -NotificationGroup "Demo" -Theme "Error" -DisplayBehaviour KeepAfterDisplay -HorizontalAlignment Center -VerticalAlignment "Center" -PresentationBehaviour "Ignore" -DisplayDuration "00:00:20" -Sound LoopingAlarm10 -DisplayAsAlarm $true -MessageHeader "ATTENTION!" -Message2 "This is a very important Message"