function Write-MmsConfig {
	<#
	.SYNOPSIS
		Writes the connection configuration file as UTF-8 without BOM.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[psobject]
		$Config,

		[Parameter()]
		[string]
		$Path = (Get-MmsConfigPath)
	)

	$directory = Split-Path -Path $Path -Parent
	if (-not (Test-Path -LiteralPath $directory)) {
		New-Item -ItemType Directory -Path $directory -Force | Out-Null
	}

	$payload = [pscustomobject]@{
		DefaultProfile = $Config.DefaultProfile
		Profiles       = $Config.Profiles
	}

	$json = $payload | ConvertTo-Json -Depth 6
	[System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}
