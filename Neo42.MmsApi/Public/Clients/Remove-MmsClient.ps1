function Remove-MmsClient {
	<#
	.SYNOPSIS
		Deletes a client and all of its plug-in reports from the MMS database.
	.DESCRIPTION
		Wraps the documented route
			DELETE /api/ServiceInfrastructureV3/{id}

		That route is the supported way to remove a client: the server maps it to
		RemoveClientById, which drops the client together with the reports of every
		plug-in (BitLocker, Device Information, WSUS, ...). The older
		DELETE /api/Client/{id} is marked obsolete in the server and is not used
		here.

		This cannot be undone. The client re-appears with an empty history as soon
		as its client component contacts the server again.
	.PARAMETER ClientId
		MMS client id. Accepts pipeline input from Get-MmsClient.
	.EXAMPLE
		Remove-MmsClient -ClientId $client.Id -WhatIf
		Shows what would be deleted without changing anything.
	.EXAMPLE
		Get-MmsClient | Where-Object { $_.LastAccess -lt (Get-Date).AddDays(-90) } | Remove-MmsClient
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
		[Alias('Id')]
		[guid]
		$ClientId,

		[Parameter()]
		[object]
		$Session
	)

	process {
		if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target "client $ClientId" -Action 'Delete the client and all of its plug-in reports')) {
			return
		}

		# The confirmation happened here with the client id in the message, so the
		# generic prompt of Invoke-MmsApiRequest is suppressed.
		$null = Invoke-MmsApiRequest -Path ('/api/ServiceInfrastructureV3/{0}' -f $ClientId) -Method DELETE `
			-Session $Session -Confirm:$false
	}
}
