function Get-MmsBitLockerRecoveryKeyBackup {
	<#
	.SYNOPSIS
		Returns backed up (purged) BitLocker recovery keys.
	.DESCRIPTION
		Wraps the documented routes of the 'BitLocker Plug-in - Recovery Keys'
		group:
			GET /api/BitlockerRecoveryKeyBackup              all backups
			GET /api/BitlockerRecoveryKeyBackup/{clientId}   backups of one client

		These are keys of volumes that no longer exist in the current report, for
		example after a re-encryption or a re-install. They are the last resort
		when a current key does not unlock a volume.

		Recovery keys are secrets. Do not write the result to a transcript or an
		unprotected file.
	.PARAMETER ClientId
		MMS client id. Without it all backups are returned.
	.EXAMPLE
		Get-MmsBitLockerRecoveryKeyBackup
	.EXAMPLE
		Get-MmsBitLockerRecoveryKeyBackup -ClientId $client.Id
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ByClient', Mandatory = $true, Position = 0)]
		[guid]
		$ClientId,

		[Parameter()]
		[object]
		$Session
	)

	$path = if ($PSCmdlet.ParameterSetName -eq 'ByClient') {
		'/api/BitlockerRecoveryKeyBackup/{0}' -f $ClientId
	}
	else {
		'/api/BitlockerRecoveryKeyBackup'
	}

	return Invoke-MmsApiRequest -Path $path -Session $Session
}
