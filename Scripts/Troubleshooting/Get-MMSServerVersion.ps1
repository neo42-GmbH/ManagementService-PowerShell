#requires -version 5
<#
.SYNOPSIS
	Get the current version of the MMS server
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to get the current version of the MMS server.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.OUTPUTS
	none
.NOTES
	Version:		1.0
	Author:			neo42 GmbH
	Creation Date:	30.11.2023
	Purpose/Change:	Initial version

.EXAMPLE
	.\Get-MMSServerVersion.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName
)

try {
	$url = "$ServerName/api/Version"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-Neo42-Auth", "Admin")
	Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials -ErrorAction Stop
}
catch {
	$error[0]
}
