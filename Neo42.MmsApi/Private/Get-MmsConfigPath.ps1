function Get-MmsConfigPath {
	<#
	.SYNOPSIS
		Returns the path of the connection configuration file.
	.DESCRIPTION
		Connection information is deliberately kept outside of the module.
		Order of resolution:
			1. Environment variable NEO42_MMS_CONFIG (full path to a json file)
			2. %USERPROFILE%\.neo42\mms.json
		The file contains host names only. Authentication is Windows integrated,
		so there are never any secrets in it.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	if (-not [string]::IsNullOrWhiteSpace($env:NEO42_MMS_CONFIG)) {
		return $env:NEO42_MMS_CONFIG
	}

	return (Join-Path -Path (Join-Path -Path $env:USERPROFILE -ChildPath '.neo42') -ChildPath 'mms.json')
}
