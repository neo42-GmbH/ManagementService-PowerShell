#requires -version 5
<#
.SYNOPSIS
	Sends a MMS Message to a Client
.DESCRIPTION
	This Script enables you to automate messages to clients utilizting the neo42 Management Service
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER Domain
	The domain of the client.
.PARAMETER ClientName
	The name of the client.
.PARAMETER Header
	The first line of the message.
.PARAMETER BodyLineOne
	The second line of the message.
.PARAMETER BodyLineTwo
	The third line of the message.
.OUTPUTS
	Message Details
.NOTES
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	29.11.2023
	Purpose/Change:	Align with new api and coding standards
.COMPONENT
	neo42 Management Service 
.EXAMPLE
	.\Send-MmsMessage.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client" -Header "Header" -BodyLineOne "BodyLineOne" -BodyLineTwo "BodyLineTwo"
#>
[CmdletBinding()]
param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $true)]
	[String]
	$Domain,
	[parameter(Mandatory = $true)]
	[String]
	$ClientName,
	[Parameter(Mandatory = $true)]
	[String]
	$Header,
	[Parameter(Mandatory = $false)]
	[String]
	$BodyLineOne,
	[Parameter(Mandatory = $false)]
	[String]
	$BodyLineTwo
	
)

# Setup header
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

# Search client
$clientsearchurl = "$ServerName/api/client/$Domain/$ClientName"
$client = Invoke-RestMethod -Method Get -Uri $clientsearchurl -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$msgObj = @{
	Id                       = (New-Guid).Guid
	ClientId                 = $client.Id
	IsSent                   = $false
	ExpirationDate           = $null
	SentTime                 = $(Get-Date -Format yyyy-MM-ddTHH:mm:ss)
	SentTimeOffset           = "02:00:00"
	ClientRecievedTime       = "0001-01-01T00:00:00"
	ClientRecievedTimeOffset = "00:00:00"
	Notification             = @{
		Id            = $msgId
		Actions       = [array]@(
			@{
				'<ActionType>k__BackingField'  = 0
				'<Arguments>k__BackingField'   = $null
				'<ProcessPath>k__BackingField' = $null
			}
		)
		ApplicationId = $null
		Lines         = [array]@(
			$Header
		)
		Icon          = $null
		IconData      = $null
		Type          = 7
		Sound         = 0
	}
}

@($BodyLineOne, $BodyLineTwo) | ForEach-Object {
	if ($true -ne [String]::IsNullOrEmpty($_)) {
		$msgObj.Notification.Lines += $_
	}
}

$body = [System.Text.RegularExpressions.Regex]::Unescape(($msgObj | ConvertTo-Json -Depth 10 -Compress))

# Push notification to client
$notificationPushUri = "$ServerName/api/StoreableNotification"
Invoke-RestMethod -Method Post -Uri $notificationPushUri -Headers $headers -UseDefaultCredentials -Body $body -ContentType "application/json; charset=utf-8" -ErrorAction Stop