function Connect-MmsApi {
	<#
	.SYNOPSIS
		Opens a session against an MMS server and makes it the default.
	.DESCRIPTION
		Verifies the address by reading /api/Version, builds a session object and
		stores it as the default for every following call in this PowerShell
		session. The object is also returned, so several servers can be addressed
		from one script by passing it to -Session.

		Authentication modes:
			-UseDefaultCredential  (default) the logged on Windows user
			-Credential            an explicit Windows account (Negotiate/NTLM)

		Both produce a Windows principal, which is what the API expects: routes
		guarded by the server side WinAuthorize attribute (client deletion, for
		example) evaluate a Windows principal and nothing else. The MMS server
		does not issue API tokens for administrative access, so there is no
		bearer token mode here.

		Credentials live only in the returned object, never in the configuration
		file.

		If the server version differs from the version of the local swagger
		snapshot, a hint to refresh the API catalog is written.
	.PARAMETER ServerName
		Address of the API, for example 'https://server.domain:4242'.
		This is not the address of the Blazor UI: the API has its own port.
	.PARAMETER ConnectionProfile
		Name of a stored profile (see Get-MmsConnectionProfile).
	.PARAMETER UseDefaultCredential
		Authenticate as the logged on Windows user. This is the default and only
		needs to be written out when a script wants to be explicit about it.
	.PARAMETER Credential
		Authenticate as another Windows account.
	.PARAMETER Persist
		Additionally stores the address as a profile under -ProfileName.
	.PARAMETER ProfileName
		Profile name used by -Persist. Defaults to the host name.
	.PARAMETER PassThru
		Returns the session object. Without it the function stays silent, which
		keeps the output of the example scripts clean.
	.EXAMPLE
		Connect-MmsApi -ServerName 'https://server.domain:4242'
	.EXAMPLE
		Connect-MmsApi -ServerName 'https://server.domain:4242' -Credential (Get-Credential) -PassThru
	.EXAMPLE
		$lab = Connect-MmsApi -ServerName 'https://lab.domain:4242' -PassThru
		Get-MmsClient -Session $lab
		Addresses a second server without changing the session default.
	.EXAMPLE
		Connect-MmsApi -ConnectionProfile 'Lab'
	#>
	[CmdletBinding(DefaultParameterSetName = 'ByServerName')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ByServerName', Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[Alias('BaseUri')]
		[string]
		$ServerName,

		[Parameter(ParameterSetName = 'ByProfile', Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$ConnectionProfile,

		[Parameter()]
		[switch]
		$UseDefaultCredential,

		[Parameter()]
		[pscredential]
		$Credential,

		[Parameter(ParameterSetName = 'ByServerName')]
		[switch]
		$Persist,

		[Parameter(ParameterSetName = 'ByServerName')]
		[string]
		$ProfileName,

		[Parameter()]
		[switch]
		$PassThru
	)

	$requested = @()
	if ($PSBoundParameters.ContainsKey('Credential')) {
		$requested += 'Credential'
	}
	if ($UseDefaultCredential) {
		$requested += 'Windows'
	}
	if ($requested.Count -gt 1) {
		throw "Choose one authentication: -UseDefaultCredential or -Credential. Requested: $($requested -join ', ')"
	}

	$authMode = if ($requested.Count -eq 1) {
		$requested[0]
	}
	else {
		'Windows'
	}

	# The address comes from the parameter or from a profile, never from the
	# ambient session: Connect-MmsApi is what creates that session.
	if ($PSCmdlet.ParameterSetName -eq 'ByProfile') {
		$entry = Get-MmsConnectionProfile -Name $ConnectionProfile -ErrorAction Stop
		$address = Format-MmsServerName -ServerName $entry.ServerName
		$sourceProfile = $entry.Name
	}
	else {
		$address = Format-MmsServerName -ServerName $ServerName
		$sourceProfile = $null
	}

	$session = New-MmsApiSessionObject -ServerName $address -ProfileName $sourceProfile -AuthMode $authMode `
		-Credential $Credential -Source 'Connect-MmsApi'

	# Verify address and authentication in one go before anything is stored.
	$version = Get-MmsServerVersion -Session $session
	$session.ServerVersion = $version

	if ($Persist) {
		$name = $ProfileName
		if ([string]::IsNullOrWhiteSpace($name)) {
			$name = ([System.Uri]$address).Host.Split('.')[0]
		}
		Set-MmsConnectionProfile -Name $name -ServerName $address | Out-Null
		$session.ProfileName = $name
	}

	$script:MmsSession = $session

	$snapshot = Get-MmsApiSnapshotMeta
	if ($null -ne $snapshot -and -not [string]::IsNullOrWhiteSpace($snapshot.ServerVersion)) {
		if ($snapshot.ServerVersion -ne [string]$version) {
			Write-Warning ("The API catalog was created for MMS $($snapshot.ServerVersion), this server runs $version. " +
				"Refresh it with Tools\Update-MmsApiCatalog.ps1.")
		}
	}

	if ($PassThru) {
		return $session
	}
}
