function Test-MmsDocumentedRoute {
	<#
	.SYNOPSIS
		Checks whether a method/path combination is part of the documented API.
	.DESCRIPTION
		Only routes published through the swagger documentation are considered
		released for automation. Undocumented routes may be changed or removed
		in any MMS release without notice, so calls against them are flagged.

		Swagger path templates such as /api/laps/{id} are turned into regular
		expressions, so a concrete request path with a real GUID still matches.

		Returns $true when documented, $false when not, and $null when the check
		could not be performed (no snapshot available).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Method,

		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)

	try {
		$document = Get-MmsSwaggerDocument
	}
	catch {
		Write-Verbose "Route check skipped: $($_.Exception.Message)"
		return $null
	}

	if ($null -eq $script:MmsRoutePatternCache) {
		$script:MmsRoutePatternCache = @{}
		foreach ($route in ConvertTo-MmsRouteObject -SwaggerDocument $document) {
			# /api/laps/{id} -> ^/api/laps/[^/]+$
			$pattern = '^' + (($route.Path -split '(\{[^}]+\})' | ForEach-Object {
						if ($_ -match '^\{[^}]+\}$') { '[^/]+' } else { [regex]::Escape($_) }
					}) -join '') + '$'
			$key = '{0} {1}' -f $route.Method, $pattern
			$script:MmsRoutePatternCache[$key] = $route
		}
	}

	$normalized = '/' + $Path.TrimStart('/')
	$normalized = ($normalized -split '\?')[0].TrimEnd('/')
	if ([string]::IsNullOrEmpty($normalized)) {
		$normalized = '/'
	}

	foreach ($key in $script:MmsRoutePatternCache.Keys) {
		$parts = $key -split ' ', 2
		if ($parts[0] -ne $Method.ToUpperInvariant()) {
			continue
		}
		if ($normalized -match $parts[1] -or "$normalized/" -match $parts[1]) {
			return $true
		}
	}

	return $false
}
