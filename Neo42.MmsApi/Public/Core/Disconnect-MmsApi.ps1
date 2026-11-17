function Disconnect-MmsApi {
	<#
	.SYNOPSIS
		Discards the session created by Connect-MmsApi.
	.DESCRIPTION
		Removes the session default of this PowerShell session, including a
		credential it carries. Calls after this need an explicit -Session again,
		or they fall back to the default profile.

		Nothing is removed from disk: connection profiles stay untouched.
	.EXAMPLE
		Disconnect-MmsApi
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
	[OutputType([void])]
	param ()

	if ($null -eq $script:MmsSession) {
		Write-Verbose 'No active MMS session.'
		return
	}

	if (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target $script:MmsSession.ServerName -Action 'Close the MMS session') {
		$script:MmsSession = $null
	}
}
