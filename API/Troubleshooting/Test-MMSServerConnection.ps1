#requires -version 5
<#
.SYNOPSIS
	Tests the connection to the Management Service Server
.DESCRIPTION
	If this scripts returns the current server time, then the following criterias are fulfilled:
		- The servername and the port are correct
		- The webserver port is not blocked by any firewall
		- The servername is a valid DNS name
		- The client trusts the webserver certificate 
		- The webserver is started
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.OUTPUTS
	none
.NOTES
	Version:		1.1
	Author:			neo42 GmbH
	Creation Date:	29.11.2023
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod

.EXAMPLE
	.\Test-MMSServerConnection.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

try {
	# Get-MmsServerTime asks /api/TimeService/1, the route that answers without an
	# authenticated user. Test-MmsApiConnection reports the same probe plus
	# authentication and API documentation, each one separately.
	Get-MmsServerTime
}
catch {
	$error[0]
}
