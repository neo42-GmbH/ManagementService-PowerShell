function Get-MmsConnectionProfile {
	<#
	.SYNOPSIS
		Lists the stored MMS connection profiles.
	.DESCRIPTION
		Profiles live in a json file outside of this module (by default
		%USERPROFILE%\.neo42\mms.json) and contain nothing but an address and an
		optional description. Credentials are never written to disk: they only
		exist in the session object created by Connect-MmsApi.
	.PARAMETER Name
		Return only the profile with this name. Fails if it does not exist.
	.EXAMPLE
		Get-MmsConnectionProfile
		Lists all known profiles and marks the default one.
	.EXAMPLE
		Get-MmsConnectionProfile -Name 'Lab'
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Position = 0)]
		[string]
		$Name
	)

	$config = Read-MmsConfig

	$profiles = foreach ($entry in $config.Profiles.PSObject.Properties) {
		# BaseUri is the key name used by earlier builds of this module. Read both
		# so that an existing mms.json keeps working after the rename.
		$address = $entry.Value.ServerName
		if ([string]::IsNullOrWhiteSpace($address)) {
			$address = $entry.Value.BaseUri
		}
		[pscustomobject]@{
			Name        = $entry.Name
			ServerName  = $address
			Description = $entry.Value.Description
			IsDefault   = ($entry.Name -eq $config.DefaultProfile)
			ConfigPath  = $config.ConfigPath
		}
	}

	if ([string]::IsNullOrWhiteSpace($Name)) {
		return $profiles
	}

	$match = @($profiles | Where-Object { $_.Name -eq $Name })
	if (0 -eq $match.Count) {
		$known = ($profiles | ForEach-Object { $_.Name }) -join ', '
		throw "No MMS connection profile named '$Name' in '$($config.ConfigPath)'. Known profiles: $known"
	}

	return $match[0]
}
