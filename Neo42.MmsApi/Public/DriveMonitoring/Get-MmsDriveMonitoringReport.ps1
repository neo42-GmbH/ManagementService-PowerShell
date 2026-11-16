function Get-MmsDriveMonitoringReport {
	<#
	.SYNOPSIS
		Returns the drive monitoring reports of the MMS clients.
	.DESCRIPTION
		Wraps the documented routes of the 'Drive Monitoring Plug-in' group:
			GET /api/DriveMonitoringReport        all reports (paged)
			GET /api/DriveMonitoringReport/{id}   the report of one client

		The report lists the drives of a client with their size and free space.
		Join it with Get-MmsClient over ClientId.
	.PARAMETER ClientId
		MMS client id. Returns the report of that single client.
	.PARAMETER Limit
		Maximum number of reports per request. Only for the list form.
	.PARAMETER Offset
		Number of reports to skip. Only for the list form.
	.PARAMETER ChangedAfter
		Only reports that changed after this point in time. Sent as ticks.
	.EXAMPLE
		Get-MmsDriveMonitoringReport
	.EXAMPLE
		Get-MmsDriveMonitoringReport -ClientId $client.Id
	.EXAMPLE
		Get-MmsDriveMonitoringReport -ChangedAfter (Get-Date).AddDays(-1)
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

		[Parameter(ParameterSetName = 'All')]
		[datetime]
		$ChangedAfter,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
	}

	if ($PSCmdlet.ParameterSetName -eq 'ById') {
		return Invoke-MmsApiRequest -Path ('/api/DriveMonitoringReport/{0}' -f $ClientId) @request
	}

	$query = @{}
	if ($PSBoundParameters.ContainsKey('Limit')) {
		$query['limit'] = $Limit
	}
	if ($PSBoundParameters.ContainsKey('Offset')) {
		$query['offset'] = $Offset
	}
	if ($PSBoundParameters.ContainsKey('ChangedAfter')) {
		$query['ticks'] = $ChangedAfter.Ticks
	}

	return Invoke-MmsApiRequest -Path '/api/DriveMonitoringReport' -Query $query @request
}
