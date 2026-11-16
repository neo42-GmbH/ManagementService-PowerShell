function Read-MmsConfig {
	<#
	.SYNOPSIS
		Reads the connection configuration file, or returns an empty structure.
	.OUTPUTS
		PSCustomObject with the properties DefaultProfile and Profiles.
	#>
	[CmdletBinding()]
	param (
		[Parameter()]
		[string]
		$Path = (Get-MmsConfigPath)
	)

	if (-not (Test-Path -LiteralPath $Path)) {
		return [pscustomobject]@{
			DefaultProfile = $null
			Profiles       = [pscustomobject]@{}
			ConfigPath     = $Path
			Exists         = $false
		}
	}

	try {
		$config = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
	}
	catch {
		throw "The MMS connection configuration '$Path' is not valid json: $($_.Exception.Message)"
	}

	if ($null -eq $config.Profiles) {
		$config | Add-Member -NotePropertyName 'Profiles' -NotePropertyValue ([pscustomobject]@{}) -Force
	}
	$config | Add-Member -NotePropertyName 'ConfigPath' -NotePropertyValue $Path -Force
	$config | Add-Member -NotePropertyName 'Exists' -NotePropertyValue $true -Force

	return $config
}
