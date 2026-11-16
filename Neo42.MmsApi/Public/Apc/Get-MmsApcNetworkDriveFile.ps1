function Get-MmsApcNetworkDriveFile {
	<#
	.SYNOPSIS
		Lists files on a network drive of the APC.
	.DESCRIPTION
		POST /api/apc/NetworkDrive/Files with
		{ NetworkDriveId, Recursive, Pattern, OnlyPackages }

		A POST that only reads: the server scans the share and returns the hits.
		This is how a file is picked before a pipeline is triggered with
		NetworkDriveId and NetworkDriveFilePath.

		Because the route is a POST it goes through ShouldProcess: with -WhatIf
		the scan is not sent and nothing is returned.
	.PARAMETER NetworkDriveId
		Drive to scan, see Get-MmsApcNetworkDrive.
	.PARAMETER Pattern
		File pattern, for example '*.msi'.
	.PARAMETER Recursive
		Include subdirectories.
	.PARAMETER OnlyPackages
		Only files the APC recognises as packages.
	.EXAMPLE
		Get-MmsApcNetworkDriveFile -NetworkDriveId $driveId -Pattern '*.msi' -Recursive
	.EXAMPLE
		Get-MmsApcNetworkDriveFile -NetworkDriveId $driveId -OnlyPackages
	#>
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[guid]
		$NetworkDriveId,

		[Parameter(Position = 1)]
		[string]
		$Pattern,

		[Parameter()]
		[switch]
		$Recursive,

		[Parameter()]
		[switch]
		$OnlyPackages,

		[Parameter()]
		[object]
		$Session
	)

	$body = @{
		NetworkDriveId = [string]$NetworkDriveId
		Recursive      = [bool]$Recursive
		OnlyPackages   = [bool]$OnlyPackages
	}
	if (-not [string]::IsNullOrWhiteSpace($Pattern)) {
		$body['Pattern'] = $Pattern
	}

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ("network drive $NetworkDriveId") -Action 'List the files on the share')) {
		return
	}

	return Invoke-MmsApiRequest -Path '/api/apc/NetworkDrive/Files' -Method POST -Body $body -Session $Session -Unwrap -Confirm:$false
}
