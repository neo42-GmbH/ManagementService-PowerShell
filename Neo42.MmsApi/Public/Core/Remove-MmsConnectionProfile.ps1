function Remove-MmsConnectionProfile {
	<#
	.SYNOPSIS
		Removes an MMS connection profile.
	.PARAMETER Name
		Name of the profile to remove.
	.EXAMPLE
		Remove-MmsConnectionProfile -Name 'OldServer'
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Name
	)

	$config = Read-MmsConfig
	if ($null -eq $config.Profiles.PSObject.Properties[$Name]) {
		Write-Warning "No MMS connection profile named '$Name' in '$($config.ConfigPath)'. Nothing to do."
		return
	}

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target $config.ConfigPath -Action "Remove profile '$Name'")) {
		return
	}

	$config.Profiles.PSObject.Properties.Remove($Name)
	if ($config.DefaultProfile -eq $Name) {
		$remaining = @($config.Profiles.PSObject.Properties | ForEach-Object { $_.Name })
		$config | Add-Member -NotePropertyName 'DefaultProfile' -NotePropertyValue (@($remaining)[0]) -Force
	}

	Write-MmsConfig -Config $config -Path $config.ConfigPath
}
