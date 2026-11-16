function Get-MmsBitLockerRecoveryKey {
	<#
	.SYNOPSIS
		Returns the BitLocker recovery keys of a client.
	.DESCRIPTION
		Wraps the documented routes of the 'BitLocker Plug-in - Recovery Keys'
		group. A client can have keys in two places, and they do not have to
		agree, which is exactly what a recovery key report is for:

			-Source Mms   GET /api/BitlockerInbuiltRecoveryKey?clientId=
			              keys stored in the MMS database
			-Source Ad    GET /api/BitlockerAdRecoveryKey?clientId=
			              keys read from Active Directory

		Both routes also exist in a /{id} form. That form answers with the literal
		string 'null' instead of a key, so this function always uses the query
		form, which returns a proper array.

		Key values are base64 encoded, decode them with
		[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.Key)).

		Recovery keys are secrets. Do not write the result to a transcript or an
		unprotected file.
	.PARAMETER ClientId
		MMS client id.
	.PARAMETER Source
		Where to read the keys from: 'Mms' (default) or 'Ad'.
	.EXAMPLE
		Get-MmsBitLockerRecoveryKey -ClientId $client.Id
	.EXAMPLE
		Get-MmsClient | Get-MmsBitLockerRecoveryKey -Source Ad
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
		[Alias('Id')]
		[guid]
		$ClientId,

		[Parameter(Position = 1)]
		[ValidateSet('Mms', 'Ad')]
		[string]
		$Source = 'Mms',

		[Parameter()]
		[object]
		$Session
	)

	process {
		$route = if ($Source -eq 'Ad') {
			'/api/BitlockerAdRecoveryKey'
		}
		else {
			'/api/BitlockerInbuiltRecoveryKey'
		}

		return Invoke-MmsApiRequest -Path $route -Query @{ clientId = $ClientId } `
			-Session $Session
	}
}
