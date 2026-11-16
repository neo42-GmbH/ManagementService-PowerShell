function Get-MmsApiSession {
	<#
	.SYNOPSIS
		Returns the session created by Connect-MmsApi.
	.DESCRIPTION
		Shows which server the next call would use, under which identity, and
		which server version was seen when the session was opened. Returns
		nothing when no session is active.

		The Credential property is part of the object because the request
		pipeline needs it. Do not write the object to disk or to a transcript.
	.EXAMPLE
		Get-MmsApiSession
	.EXAMPLE
		Get-MmsApiSession | Select-Object ServerName, AuthMode, User, ServerVersion
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param ()

	if ($null -eq $script:MmsSession) {
		Write-Verbose 'No active MMS session. Run Connect-MmsApi first.'
		return
	}

	return $script:MmsSession
}
