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
	Purpose/Change:	Use the Neo42.MmsApi module instead of raw Invoke-RestMethod

.EXAMPLE
	.\Get-MMSServerVersion.ps1 -ServerName "https://server.domain:4242"
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
	Get-MmsServerVersion
}
catch {
	$error[0]
}
