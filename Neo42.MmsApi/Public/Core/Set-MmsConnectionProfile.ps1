function Set-MmsConnectionProfile {
	<#
	.SYNOPSIS
		Creates or updates an MMS connection profile.
	.DESCRIPTION
		Stores the API address under a name in the configuration file outside of
		the module. Note that the API listener has its own port (4242 by default)
		and is not the address of the Blazor UI.

		Only the address is stored. Credentials and tokens are never persisted.
	.PARAMETER Name
		Name of the profile, for example the server short name.
	.PARAMETER ServerName
		Address of the API, for example 'https://server.domain:4242'.
	.PARAMETER Description
		Optional note, for example 'lab' or 'customer test system'.
	.PARAMETER SetAsDefault
		Makes this profile the default for all calls without an explicit target.
	.EXAMPLE
		Set-MmsConnectionProfile -Name 'Lab' -ServerName 'https://server.domain:4242' -Description 'Lab' -SetAsDefault
	#>
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Name,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[Alias('BaseUri')]
		[string]
		$ServerName,

		[Parameter()]
		[string]
		$Description,

		[Parameter()]
		[switch]
		$SetAsDefault
	)

	$normalized = Format-MmsServerName -ServerName $ServerName
	$config = Read-MmsConfig

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target $config.ConfigPath -Action "Store profile '$Name' ($normalized)")) {
		return
	}

	$config.Profiles | Add-Member -NotePropertyName $Name -NotePropertyValue ([pscustomobject]@{
			ServerName  = $normalized
			Description = $Description
		}) -Force

	if ($SetAsDefault -or [string]::IsNullOrWhiteSpace($config.DefaultProfile)) {
		$config | Add-Member -NotePropertyName 'DefaultProfile' -NotePropertyValue $Name -Force
	}

	Write-MmsConfig -Config $config -Path $config.ConfigPath

	return (Get-MmsConnectionProfile -Name $Name)
}
