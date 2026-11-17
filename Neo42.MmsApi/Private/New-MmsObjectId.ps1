function New-MmsObjectId {
	<#
	.SYNOPSIS
		Returns a new MongoDB style ObjectId as a 24 character hex string.
	.DESCRIPTION
		Pipelines, phases and tasks in the APC plug-in are identified by MongoDB
		ObjectIds, and the server decides between insert and update by looking the
		id up: an id it does not know is inserted under exactly that id, an id it
		knows is overwritten. Creating a pipeline therefore means generating ids
		that cannot collide with an existing document.

		The layout follows the ObjectId specification closely enough for that
		purpose: 4 bytes big endian Unix seconds, then 8 random bytes. The random
		part is drawn from a cryptographic RNG rather than Get-Random, so two
		calls in the same second stay distinct.
	.OUTPUTS
		String. 24 lower case hex characters.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	$seconds = [uint32][System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
	$timePart = [System.BitConverter]::GetBytes($seconds)
	if ([System.BitConverter]::IsLittleEndian) {
		[array]::Reverse($timePart)
	}

	$randomPart = [byte[]]::new(8)
	$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
	try {
		$rng.GetBytes($randomPart)
	}
	finally {
		$rng.Dispose()
	}

	return (($timePart + $randomPart) | ForEach-Object { $_.ToString('x2') }) -join ''
}
