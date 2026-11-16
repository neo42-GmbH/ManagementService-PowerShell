function Invoke-MmsApiRequest {
	<#
	.SYNOPSIS
		Sends a request to the neo42 Management Service API.
	.DESCRIPTION
		Single entry point for every call of this module. It handles the parts
		that are identical for all endpoints:
			- resolving the target server (session, or the default profile)
			- authentication (Windows integrated or credential)
			- the mandatory X-Neo42-Auth header
			- json serialization of a request body
			- readable errors including status code and response body
			- -WhatIf / -Confirm for every request that is not a GET
			- a warning when a route is not part of the documented API surface

		The deserialized response is returned unchanged. The API uses several
		response shapes (bare array, { Success, Item, Error }, { data }), so
		unwrapping is opt-in via -Unwrap and normally done by the endpoint
		specific wrapper functions.
	.PARAMETER Path
		Route relative to the address, for example '/api/Client'.
	.PARAMETER Method
		HTTP method. Everything except GET runs through ShouldProcess.
	.PARAMETER Query
		Query string parameters. Values are url encoded.
	.PARAMETER Body
		Request body. A string is sent as is, anything else is converted to json.
	.PARAMETER AuthMode
		Value of the X-Neo42-Auth header. 'Admin' for administrative calls,
		'Anonymous' for the few endpoints that do not require an authenticated
		user (for example /api/TimeService/1), 'None' omits the header entirely.
		This is the API role header, not the way the caller authenticates - that
		part comes from the session.
	.PARAMETER ControllerVersion
		Optional X-Neo42-ControllerVersion header. Only needed for endpoints that
		are versioned by header instead of by path.
	.PARAMETER TimeoutSec
		Request timeout, default 300 seconds. Some report endpoints are slow.
	.PARAMETER Unwrap
		Unwraps the known response envelopes: { Success, Item, Error } returns
		Item (and throws when Success is false), { data } returns data.
	.PARAMETER Raw
		Returns the response body as text instead of a deserialized object. Needed
		for anything that is not json, and for saving a document unchanged (the
		swagger snapshot in Tools\Update-MmsApiCatalog.ps1 uses it).
	.PARAMETER SkipRouteCheck
		Suppresses the warning for routes that are not published in swagger.

		Not a general opt-out: this module wraps published routes only, so the
		warning is a finding. It exists for the two cases where the check cannot
		apply - fetching the swagger document itself (Tools\Update-MmsApiCatalog.ps1)
		and a snapshot that is older than the server.
	.EXAMPLE
		Invoke-MmsApiRequest -Path '/api/Version'
	.EXAMPLE
		Invoke-MmsApiRequest -Path '/api/apc/tenant/all' -Unwrap
	.EXAMPLE
		Invoke-MmsApiRequest -Path '/api/apc/EmpirumCleanupJob' -Method POST -Body @{ TenantId = $id } -WhatIf
		Shows what would be sent without changing anything on the server.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Path,

		[Parameter(Position = 1)]
		[ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
		[string]
		$Method = 'GET',

		[Parameter()]
		[hashtable]
		$Query,

		[Parameter()]
		[object]
		$Body,

		[Parameter()]
		[string]
		$AuthMode = 'Admin',

		[Parameter()]
		[int]
		$ControllerVersion,

		[Parameter()]
		[object]
		$Session,

		[Parameter()]
		[int]
		$TimeoutSec = 300,

		[Parameter()]
		[switch]
		$Unwrap,

		[Parameter()]
		[switch]
		$Raw,

		[Parameter()]
		[switch]
		$SkipRouteCheck
	)

	$target = Resolve-MmsApiSession -Session $Session
	$relativePath = '/' + $Path.TrimStart('/')

	$url = '{0}{1}' -f $target.ServerName, $relativePath
	if ($null -ne $Query -and $Query.Count -gt 0) {
		$pairs = foreach ($key in $Query.Keys) {
			$value = $Query[$key]
			if ($null -eq $value) {
				continue
			}
			'{0}={1}' -f [System.Uri]::EscapeDataString([string]$key), [System.Uri]::EscapeDataString([string]$value)
		}
		if (@($pairs).Count -gt 0) {
			$url = '{0}?{1}' -f $url, (@($pairs) -join '&')
		}
	}

	if (-not $SkipRouteCheck) {
		$documented = Test-MmsDocumentedRoute -Method $Method -Path $relativePath
		if ($false -eq $documented) {
			$cacheKey = '{0} {1}' -f $Method, $relativePath
			if ($null -eq $script:MmsUndocumentedRouteWarnings) {
				$script:MmsUndocumentedRouteWarnings = @{}
			}
			if (-not $script:MmsUndocumentedRouteWarnings.ContainsKey($cacheKey)) {
				$script:MmsUndocumentedRouteWarnings[$cacheKey] = $true
				Write-Warning ("'$Method $relativePath' is not part of the documented API surface. " +
					"Undocumented routes can change or disappear in any MMS release without notice. " +
					"Check Find-MmsApiRoute for a documented alternative.")
			}
		}
	}

	$headers = @{}
	if ($AuthMode -ne 'None') {
		$headers['X-Neo42-Auth'] = $AuthMode
	}
	if ($PSBoundParameters.ContainsKey('ControllerVersion')) {
		$headers['X-Neo42-ControllerVersion'] = [string]$ControllerVersion
	}

	$parameters = @{
		Uri             = $url
		Method          = $Method
		Headers         = $headers
		UseBasicParsing = $true
		TimeoutSec      = $TimeoutSec
		ErrorAction     = 'Stop'
	}

	Add-MmsAuthentication -Parameters $parameters -Headers $headers -Session $target

	if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
		if ($Method -eq 'GET') {
			Write-Warning 'A body was supplied for a GET request and is ignored.'
		}
		else {
			if ($Body -is [string]) {
				$parameters['Body'] = $Body
			}
			else {
				$parameters['Body'] = $Body | ConvertTo-Json -Depth 10 -Compress
			}
			$headers['Content-Type'] = 'application/json; charset=utf-8'
		}
	}

	if ($Method -ne 'GET') {
		$description = if ($parameters.ContainsKey('Body')) {
			$preview = [string]$parameters['Body']
			if ($preview.Length -gt 300) {
				$preview = $preview.Substring(0, 300) + '... [truncated]'
			}
			'{0} (body: {1})' -f $Method, $preview
		}
		else {
			$Method
		}
		if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target $url -Action $description)) {
			return
		}
	}

	Write-Verbose ("{0} {1} (server from: {2}, auth: {3})" -f $Method, $url, $target.Source, $target.AuthMode)

	try {
		if ($Raw) {
			$response = (Invoke-WebRequest @parameters).Content
		}
		else {
			$response = Invoke-RestMethod @parameters
		}
	}
	catch {
		$detail = Get-MmsWebErrorDetail -ErrorRecord $_
		$message = "MMS API call failed: $Method $url"
		if ($null -ne $detail.StatusCode) {
			$message += " -> HTTP $($detail.StatusCode) $($detail.StatusDescription)"
		}
		if (-not [string]::IsNullOrWhiteSpace($detail.AuthResult)) {
			$message += " | X-Neo42-Auth-Result: $($detail.AuthResult)"
		}
		if (-not [string]::IsNullOrWhiteSpace($detail.Body)) {
			$message += " | Response: $($detail.Body)"
		}
		if ($null -eq $detail.StatusCode) {
			$message += " | $($detail.Message)"
		}
		throw $message
	}

	if ($Raw) {
		return $response
	}

	# Several routes answer "no data" with the four characters null instead of an
	# empty body, which Invoke-RestMethod hands back as the string 'null'. Left
	# alone it survives every $null check and only fails later on a property
	# access, so it is turned into "no output" here for all callers.
	if ($response -is [string] -and $response -eq 'null') {
		return
	}

	if (-not $Unwrap) {
		return $response
	}

	if ($null -ne $response -and $null -ne $response.PSObject.Properties['Success']) {
		if (-not $response.Success) {
			$reason = $response.Error.Reason
			if ([string]::IsNullOrWhiteSpace($reason)) {
				$reason = ($response.Error | ConvertTo-Json -Depth 4 -Compress)
			}
			throw "MMS API reported a failure for $Method $url : $reason"
		}
		# Emit nothing instead of $null, so that @(Get-...).Count is 0 for an empty result.
		if ($null -eq $response.Item) {
			return
		}
		return $response.Item
	}

	# { Data, Errors, Meta } is the second envelope in use. Property lookup is case
	# insensitive, so this also covers the lower case { data } form.
	if ($null -ne $response -and $null -ne $response.PSObject.Properties['data']) {
		if ($null -ne $response.PSObject.Properties['errors'] -and @($response.errors).Count -gt 0) {
			$reason = ($response.errors | ConvertTo-Json -Depth 4 -Compress)
			throw "MMS API reported a failure for $Method $url : $reason"
		}
		if ($null -eq $response.data) {
			return
		}
		return $response.data
	}

	return $response
}
