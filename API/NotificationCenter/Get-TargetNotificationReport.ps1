#requires -version 5
<#
.SYNOPSIS
	Exports the state of all notifications of target

#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
	$ServerName,
    [Parameter(Mandatory = $true)]
	[string]
	$TargetName,
	[Parameter(Mandatory = $false)]
	[string]
	$OutputPath = "$PWD"
)

$targetsUrl = "$ServerName/api/NotificationCenter/Target/All"
$notificationsClientBaseUrl = "$ServerName/api/NotificationCenter/Notifications/Client"
$notificationsBaseUrl = "$ServerName/api/NotificationCenter/Notifications"

$filePath = Join-Path -Path $OutputPath -ChildPath "ClientNotificationReport.csv"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

$targets = Invoke-RestMethod -Method Get -Uri $targetsUrl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$target = $targets | Where-Object { $_.Name -eq $TargetName }
if ($null -eq $target) {
    throw "$TargetName was not found"
}

$notifications = @()
foreach ($clientId in $target.ClientIds) {
    $notifications += Invoke-RestMethod -Method Get -Uri ( $notificationsClientBaseUrl + "?clientId=$clientId" ) -Headers $headers -UseDefaultCredentials -ErrorAction Stop
}


$output = @()
foreach ($notification in $notifications) {
    $matchingNotificationReport = Invoke-RestMethod -Method Get -Uri ( $notificationsBaseUrl + "/" + $notification.Id ) -Headers $headers -UseDefaultCredentials -ErrorAction Stop
    $targetInfo = $matchingNotificationReport.Targets | Where-Object { $_.ClientId -in $target.ClientIds } | Select-Object -First 1

    $output += [PSCustomObject]@{
        notificationId = $notification.Id
        notificationCreated = $notification.Message.CreationDate
        notificationGroup = $notification.Message.NotificationGroup
        notificationSent = $targetInfo.IsSent
        notificationSentDate = $targetInfo.SentTime
        notificationReceivedDate = $targetInfo.ReceivedTime
        targetId = $targetInfo.ClientId
        targetName = $target.Name
    }
}

$output | Export-Csv -Path $filePath -NoTypeInformation