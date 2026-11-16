function Get-MmsMaintenanceRebootReport {
	<#
	.SYNOPSIS
		Returns the maintenance reboot reports of the MMS clients.
	.DESCRIPTION
		Wraps the documented routes of the 'Maintenance Reboot Plug-in' group:
			GET /api/MaintenanceReportV3        all reports (paged)
			GET /api/MaintenanceReportV3/{id}   the report of one client

		The report shows when a client last rebooted, whether a reboot is pending and
		which maintenance window applies.
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
		Get-MmsMaintenanceRebootReport
	.EXAMPLE
		Get-MmsMaintenanceRebootReport -ClientId $client.Id
	.EXAMPLE
		Get-MmsMaintenanceRebootReport -ChangedAfter (Get-Date).AddDays(-1)
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
		return Invoke-MmsApiRequest -Path ('/api/MaintenanceReportV3/{0}' -f $ClientId) @request
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

	return Invoke-MmsApiRequest -Path '/api/MaintenanceReportV3' -Query $query @request
}
