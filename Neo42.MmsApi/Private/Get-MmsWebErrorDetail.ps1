function Get-MmsWebErrorDetail {
	<#
	.SYNOPSIS
		Extracts status code and response body from a failed web request.
	.DESCRIPTION
		PowerShell 5.1 hides the response body of a failed Invoke-RestMethod call
		inside the WebException. Without reading it, every API error looks like
		'The remote server returned an error: (400) Bad Request.' which is useless
		for troubleshooting.

		Note on authentication: the OAuth pipeline of the MMS server forces HTTP 400
		for auth failures and reports the real result in the X-Neo42-Auth-Result
		header, so that header is surfaced here as well.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.ErrorRecord]
		$ErrorRecord
	)

	$statusCode = $null
	$statusDescription = $null
	$body = $null
	$authResult = $null

	$response = $null
	if ($ErrorRecord.Exception -is [System.Net.WebException]) {
		$response = $ErrorRecord.Exception.Response
	}
	elseif ($null -ne $ErrorRecord.Exception.PSObject.Properties['Response']) {
		$response = $ErrorRecord.Exception.Response
	}

	if ($null -ne $response) {
		try {
			$statusCode = [int]$response.StatusCode
			$statusDescription = $response.StatusDescription
			$authResult = $response.Headers['X-Neo42-Auth-Result']
		}
		catch {
			Write-Verbose "Could not read status information: $($_.Exception.Message)"
		}

		try {
			$stream = $response.GetResponseStream()
			if ($null -ne $stream) {
				$reader = New-Object System.IO.StreamReader($stream)
				try {
					$body = $reader.ReadToEnd()
				}
				finally {
					$reader.Dispose()
				}
			}
		}
		catch {
			Write-Verbose "Could not read the response body: $($_.Exception.Message)"
		}
	}

	return [pscustomobject]@{
		StatusCode        = $statusCode
		StatusDescription = $statusDescription
		AuthResult        = $authResult
		Body              = $body
		Message           = $ErrorRecord.Exception.Message
	}
}
