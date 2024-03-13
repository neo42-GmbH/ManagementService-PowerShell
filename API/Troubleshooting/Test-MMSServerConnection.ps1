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
	Purpose/Change:	Align with new api and coding standards

.EXAMPLE
	.\Test-MMSServerConnection.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName
)

try {
	$url = "$ServerName/api/TimeService/1"
	$web = New-Object System.Net.WebClient
	$web.UseDefaultCredentials = $true
	$web.Headers.Add('X-Neo42-Auth', 'Anonymous')

	$web.DownloadString($url)
}
catch {
	$error[0]
}
