function Get-MmsServiceInfrastructureReport {
	<#
	.SYNOPSIS
		Returns the service infrastructure reports of the MMS clients.
	.DESCRIPTION
		Wraps the documented routes of the 'Service Infrastructure Plug-in' group:
			GET /api/ServiceInfrastructureV3        all reports (paged)
			GET /api/ServiceInfrastructureV3/{id}   the report of one client

		The report is the client component's view of the machine: last logon user,
		agent versions, connection state and the detail data other plug-ins build
		on. Join it with Get-MmsClient over the client id.

		Both routes use the { Success, Item, Error } envelope, which is unwrapped
		here.
	.PARAMETER ClientId
		MMS client id. Returns the report of that single client.
	.PARAMETER Limit
		Maximum number of reports per request. Only for the list form.
	.PARAMETER Offset
		Number of reports to skip. Only for the list form.
	.EXAMPLE
		Get-MmsServiceInfrastructureReport
	.EXAMPLE
		Get-MmsServiceInfrastructureReport -ClientId $client.Id | Select-Object LastLoggedOnUser
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
		[Alias('Id')]
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

	process {
		$request = @{
			Session = $Session
			Unwrap            = $true
		}

		if ($PSCmdlet.ParameterSetName -eq 'ById') {
			return Invoke-MmsApiRequest -Path ('/api/ServiceInfrastructureV3/{0}' -f $ClientId) @request
		}

		$query = @{}
		if ($PSBoundParameters.ContainsKey('Limit')) {
			$query['limit'] = $Limit
		}
		if ($PSBoundParameters.ContainsKey('Offset')) {
			$query['offset'] = $Offset
		}

		return Invoke-MmsApiRequest -Path '/api/ServiceInfrastructureV3' -Query $query @request
	}
}
