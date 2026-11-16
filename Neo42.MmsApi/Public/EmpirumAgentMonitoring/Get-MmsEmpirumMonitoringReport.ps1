function Get-MmsEmpirumMonitoringReport {
	<#
	.SYNOPSIS
		Returns the Empirum agent monitoring reports of the MMS clients.
	.DESCRIPTION
		Wraps the documented routes of the 'Empirum Agent Monitoring Plug-in'
		group:
			GET /api/EmpirumMonitoringReportV2        all reports (paged)
			GET /api/EmpirumMonitoringReportV2/{id}   the report of one client

		The report carries the state of the Empirum agents on a client (framework,
		UEM, ERIS) and the Empirum group assignment. Join it with Get-MmsClient
		over ClientId.
	.PARAMETER ClientId
		MMS client id. Returns the report of that single client.
	.PARAMETER Limit
		Maximum number of reports per request. Only for the list form.
	.PARAMETER Offset
		Number of reports to skip. Only for the list form.
	.EXAMPLE
		Get-MmsEmpirumMonitoringReport
	.EXAMPLE
		Get-MmsEmpirumMonitoringReport -ClientId $client.Id
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
		return Invoke-MmsApiRequest -Path ('/api/EmpirumMonitoringReportV2/{0}' -f $ClientId) @request
	}

	$query = @{}
	if ($PSBoundParameters.ContainsKey('Limit')) {
		$query['limit'] = $Limit
	}
	if ($PSBoundParameters.ContainsKey('Offset')) {
		$query['offset'] = $Offset
	}

	return Invoke-MmsApiRequest -Path '/api/EmpirumMonitoringReportV2' -Query $query @request
}
