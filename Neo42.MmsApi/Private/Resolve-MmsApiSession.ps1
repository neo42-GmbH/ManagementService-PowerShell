function Resolve-MmsApiSession {
	<#
	.SYNOPSIS
		Determines which server and which authentication a request should use.
	.DESCRIPTION
		Every public function funnels its -Session parameter through here, so the
		precedence is defined in exactly one place. First match wins:

			1. -Session        session object from Connect-MmsApi
			2. session         the connection created by Connect-MmsApi
			3. default profile DefaultProfile from the configuration file

		Only case 3 carries an address without a sign-in, and it opens as the
		logged on Windows user. The other two bring their own, so a
		Connect-MmsApi -Credential cannot be dropped on the way to a request.
	.OUTPUTS
		PSCustomObject with the type name Neo42.MmsApi.Session.
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter()]
		[AllowNull()]
		[object]
		$Session
	)

	if ($null -ne $Session) {
		if ($null -eq $Session.ServerName) {
			throw "The value passed to -Session is not an MMS session. Create one with Connect-MmsApi."
		}
		return $Session
	}

	if ($null -ne $script:MmsSession) {
		return $script:MmsSession
	}

	$config = Read-MmsConfig
	if (-not [string]::IsNullOrWhiteSpace($config.DefaultProfile)) {
		$entry = Get-MmsConnectionProfile -Name $config.DefaultProfile -ErrorAction Stop
		return New-MmsApiSessionObject -ServerName (Format-MmsServerName -ServerName $entry.ServerName) `
			-ProfileName $entry.Name -Source 'DefaultProfile'
	}

	throw ("No MMS server known. Run Connect-MmsApi -ServerName 'https://server.domain:4242', " +
		"or create a profile with Set-MmsConnectionProfile -Name 'MyServer' -ServerName 'https://server.domain:4242' -SetAsDefault. " +
		"Configuration file: $($config.ConfigPath)")
}
