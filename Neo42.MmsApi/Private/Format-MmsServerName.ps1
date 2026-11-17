function Format-MmsServerName {
	<#
	.SYNOPSIS
		Validates and normalizes the address of an MMS API.
	.DESCRIPTION
		The API listener uses its own port (4242 by default) and is not the same
		address as the Blazor UI. Anything that is not an absolute http/https
		address is rejected here instead of failing later inside a request.

		An input without a scheme ('server.domain', 'server.domain:4242') gets
		https:// prepended. That keeps the calling convention of the example
		scripts, which pass a bare host name or a full url in -ServerName.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory = $true)]
		[Alias('BaseUri')]
		[string]
		$ServerName
	)

	$trimmed = $ServerName.Trim().TrimEnd('/')

	# No scheme at all ('server.domain', 'server.domain:4242') -> https://...
	# An explicit scheme is kept, so that anything but http/https is rejected below.
	if ($trimmed -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://') {
		$trimmed = 'https://' + $trimmed
	}

	$parsed = $null
	if (-not [System.Uri]::TryCreate($trimmed, [System.UriKind]::Absolute, [ref]$parsed)) {
		throw "'$ServerName' is not an absolute address. Expected something like 'https://server.domain:4242'."
	}
	if ($parsed.Scheme -notin @('http', 'https')) {
		throw "'$ServerName' uses the unsupported scheme '$($parsed.Scheme)'. Expected http or https."
	}

	return $trimmed
}
