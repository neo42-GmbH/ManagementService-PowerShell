function Add-MmsAuthentication {
	<#
	.SYNOPSIS
		Applies the authentication of a session to a request.
	.DESCRIPTION
		The single place that translates Session.AuthMode into what
		Invoke-RestMethod and the request headers need. Adding a new mode means
		adding one branch here, not touching every wrapper.

			Windows     -UseDefaultCredentials, the logged on user is the identity
			Credential  -Credential, sent via Negotiate/NTLM by the .NET stack
	.PARAMETER Parameters
		The splatting hashtable that is handed to Invoke-RestMethod.
	.PARAMETER Headers
		The request header hashtable referenced by that splatting hashtable.
	.PARAMETER Session
		Session object from Resolve-MmsApiSession.
	#>
	[CmdletBinding()]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true)]
		[hashtable]
		$Parameters,

		[Parameter(Mandatory = $true)]
		[hashtable]
		$Headers,

		[Parameter(Mandatory = $true)]
		[object]
		$Session
	)

	switch ($Session.AuthMode) {
		'Credential' {
			if ($null -eq $Session.Credential) {
				throw "The session uses AuthMode 'Credential' but carries no credential. Reconnect with Connect-MmsApi -Credential (Get-Credential)."
			}
			$Parameters['Credential'] = $Session.Credential
		}
		default {
			$Parameters['UseDefaultCredentials'] = $true
		}
	}
}
