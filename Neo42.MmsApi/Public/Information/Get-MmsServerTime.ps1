function Get-MmsServerTime {
	<#
	.SYNOPSIS
		Returns the current time of the MMS server.
	.DESCRIPTION
		Wraps the documented route
			GET /api/TimeService/1

		The route answers without an authenticated user (X-Neo42-Auth
		'Anonymous'), which makes it the cheapest reachability probe there is: a
		result means name resolution, port, certificate trust and the web service
		itself are all in order. Test-MmsApiConnection uses it for exactly that.
	.EXAMPLE
		Get-MmsServerTime -ServerName 'https://server.domain:4242'
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter()]
		[object]
		$Session
	)

	return Invoke-MmsApiRequest -Path '/api/TimeService/1' -AuthMode 'Anonymous' -TimeoutSec 30 `
		-Session $Session
}
