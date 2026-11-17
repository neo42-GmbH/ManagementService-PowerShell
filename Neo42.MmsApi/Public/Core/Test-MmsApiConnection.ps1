function Test-MmsApiConnection {
	<#
	.SYNOPSIS
		Checks reachability, authentication and API documentation.
	.DESCRIPTION
		Runs three probes and reports each one separately, so a failure can be
		attributed:
			1. /api/TimeService/1 with X-Neo42-Auth 'Anonymous'
			   name resolution, port reachable, certificate trusted, service running
			2. /api/Version with X-Neo42-Auth 'Admin'
			   the authentication of the session actually works
			3. /docs/v1/swagger
			   whether the API documentation is switched on for this server
			   (server setting 'EnableApiDocumentation')

		This is the function to run first when a script fails with a connection
		error, because it separates 'server not reachable' from 'not allowed'.

		It is the one wrapper that takes a bare -ServerName: Connect-MmsApi
		verifies the address before storing the session, so on a broken server
		there is no session left to diagnose with.
	.PARAMETER ServerName
		Address to probe without a session, for example
		'https://server.domain:4242'. Probes as the logged on Windows user; the
		result names the identity it used.
	.EXAMPLE
		Test-MmsApiConnection -ServerName 'https://server.domain:4242'
	.EXAMPLE
		Test-MmsApiConnection | Format-List
	#>
	[CmdletBinding(DefaultParameterSetName = 'BySession')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'BySession')]
		[object]
		$Session,

		[Parameter(ParameterSetName = 'ByServerName', Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[Alias('BaseUri')]
		[string]
		$ServerName
	)

	# Built here, not in Resolve-MmsApiSession: probing an address is the
	# opposite of resolving a session.
	$target = if ($PSCmdlet.ParameterSetName -eq 'ByServerName') {
		New-MmsApiSessionObject -ServerName (Format-MmsServerName -ServerName $ServerName) -Source 'Test-MmsApiConnection'
	}
	else {
		Resolve-MmsApiSession -Session $Session
	}

	$result = [ordered]@{
		ServerName             = $target.ServerName
		AuthMode               = $target.AuthMode
		User                   = $target.User
		Reachable              = $false
		ServerTime             = $null
		Authenticated          = $false
		ServerVersion          = $null
		ApiDocumentationActive = $false
		Errors                 = @()
	}

	try {
		$time = Invoke-MmsApiRequest -Path '/api/TimeService/1' -AuthMode 'Anonymous' -Session $target -TimeoutSec 30
		$result['Reachable'] = $true
		$result['ServerTime'] = $time
	}
	catch {
		$result['Errors'] += "TimeService: $($_.Exception.Message)"
	}

	try {
		$result['ServerVersion'] = Get-MmsServerVersion -Session $target
		$result['Authenticated'] = $true
	}
	catch {
		$result['Errors'] += "Version: $($_.Exception.Message)"
	}

	try {
		$documentationParameters = @{
			Uri             = '{0}/docs/v1/swagger' -f $target.ServerName
			UseBasicParsing = $true
			TimeoutSec      = 30
			ErrorAction     = 'Stop'
		}
		$documentationHeaders = @{}
		Add-MmsAuthentication -Parameters $documentationParameters -Headers $documentationHeaders -Session $target
		$documentationParameters['Headers'] = $documentationHeaders

		$null = Invoke-WebRequest @documentationParameters
		$result['ApiDocumentationActive'] = $true
	}
	catch {
		$result['Errors'] += "ApiDocumentation: $($_.Exception.Message)"
	}

	return [pscustomobject]$result
}
