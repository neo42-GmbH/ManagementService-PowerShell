function Get-MmsServerVersion {
	<#
	.SYNOPSIS
		Returns the version of the MMS server.
	.DESCRIPTION
		Calls GET /api/Version and converts the returned structure into a
		[version] object.
	.EXAMPLE
		Get-MmsServerVersion
	#>
	[CmdletBinding()]
	[OutputType([version])]
	param (
		[Parameter()]
		[object]
		$Session
	)

	$response = Invoke-MmsApiRequest -Path '/api/Version' -Session $Session

	$value = $response.Value
	if ($null -eq $value) {
		$value = $response
	}

	$parts = foreach ($name in '_Major', '_Minor', '_Build', '_Revision') {
		$part = $value.$name
		if ($null -eq $part -or $part -lt 0) { 0 } else { [int]$part }
	}

	return [version]::new($parts[0], $parts[1], $parts[2], $parts[3])
}
