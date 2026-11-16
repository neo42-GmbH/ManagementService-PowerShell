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
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.COMPONENT
	neo42 Management Service 
.EXAMPLE
	.\Send-MmsMessage.ps1 -ServerName "https://server.domain:4242" -Domain "domain" -ClientName "client" -Header "Header" -BodyLineOne "BodyLineOne" -BodyLineTwo "BodyLineTwo"
#>
[CmdletBinding(SupportsShouldProcess)]
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

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

# Search client
$client = Get-MmsClient -Domain $Domain -Name $ClientName
if ($null -eq $client) {
	Write-Warning "No client found for $($Domain)\$($ClientName)"
	Exit 1
}

# Send-MmsClientMessage builds the StoreableNotification body (including the
# odd '<ActionType>k__BackingField' names the server expects) and posts it to
# /api/StoreableNotification.
# -Confirm:$false keeps this script non interactive; -WhatIf shows the message
# without sending it.
Send-MmsClientMessage -ClientId $client.Id -Header $Header -Line $BodyLineOne, $BodyLineTwo -Confirm:$false
