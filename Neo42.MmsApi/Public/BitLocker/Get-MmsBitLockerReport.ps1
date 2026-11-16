function Get-MmsBitLockerReport {
	<#
	.SYNOPSIS
		Returns the BitLocker reports of the MMS clients.
	.DESCRIPTION
		Wraps the documented routes of the 'BitLocker Plug-in' group:
			GET /api/BitlockerReportV4        all reports (paged)
			GET /api/BitlockerReportV4/{id}   the report of one client

		The report carries ComplianceState, EncryptionPercentage and the current
		and target configuration. Join it with Get-MmsClient over ClientID.

		ComplianceState is a number: 0 = no report, 1 = not compliant,
		2 = compliant.
	.PARAMETER ClientId
		MMS client id. Returns the report of that single client.
	.PARAMETER Limit
		Maximum number of reports per request. Only for the list form.
	.PARAMETER Offset
		Number of reports to skip. Only for the list form.
	.EXAMPLE
		Get-MmsBitLockerReport
	.EXAMPLE
		Get-MmsBitLockerReport -ClientId $client.Id
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0)]
		[guid]
		$ClientId,

		[Parameter(ParameterSetName = 'All')]
		[int]
		$Limit,

		[Parameter(ParameterSetName = 'All')]
		[int]
		$Offset,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
	}

	if ($PSCmdlet.ParameterSetName -eq 'ById') {
		# The single report route uses the { Success, Item, Error } envelope,
		# the list route returns a bare array.
		return Invoke-MmsApiRequest -Path ('/api/BitlockerReportV4/{0}' -f $ClientId) @request -Unwrap
	}

	$query = @{}
	if ($PSBoundParameters.ContainsKey('Limit')) {
		$query['limit'] = $Limit
	}
	if ($PSBoundParameters.ContainsKey('Offset')) {
		$query['offset'] = $Offset
	}

	return Invoke-MmsApiRequest -Path '/api/BitlockerReportV4' -Query $query @request
}
