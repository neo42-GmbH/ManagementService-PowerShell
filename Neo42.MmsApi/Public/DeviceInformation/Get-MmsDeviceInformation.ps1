function Get-MmsDeviceInformation {
	<#
	.SYNOPSIS
		Returns the device information inventory of the MMS clients.
	.DESCRIPTION
		Wraps the documented routes of the 'Device Information Plug-in' group:
			GET /api/DeviceInformationV2?type=      one inventory area, all clients
			GET /api/DeviceInformationV2/{id}       the full inventory of one client

		The list form needs a -Type, because the inventory is split into areas and
		the server refuses a request without one. The single client form returns
		every area at once.

		The list form is paged and the data set is large. Page through it with
		-Limit and -Offset instead of pulling everything in one request.
	.PARAMETER Type
		Inventory area, for example 'sw' (installed software), 'cert'
		(certificates), 'os' (operating system), 'hw' (hardware). Which areas a
		server delivers depends on its plug-in configuration.

		The area decides which sub object of the record is filled - 'sw' fills
		Software, 'cert' and 'os' fill OperatingSystem, 'hw' fills Hardware, and
		the rest stay null.

		An unknown area is NOT rejected. The server answers with the usual record
		and every sub object null, so a typo looks like a client that has not
		inventoried yet. Check the sub object the area should have filled, not
		just the record count.
	.PARAMETER ClientId
		MMS client id. Returns the full inventory of that single client.
	.PARAMETER Limit
		Maximum number of records per request. Only for the list form.
	.PARAMETER Offset
		Number of records to skip. Only for the list form.
	.EXAMPLE
		Get-MmsDeviceInformation -Type 'sw'
	.EXAMPLE
		Get-MmsDeviceInformation -Type 'cert' -Limit 200 -Offset 0
	.EXAMPLE
		Get-MmsDeviceInformation -ClientId $client.Id
	#>
	[CmdletBinding(DefaultParameterSetName = 'ByType')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ByType', Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Type,

		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
		[Alias('Id')]
		[guid]
		$ClientId,

		[Parameter(ParameterSetName = 'ByType')]
		[int]
		$Limit,

		[Parameter(ParameterSetName = 'ByType')]
		[int]
		$Offset,

		[Parameter()]
		[object]
		$Session
	)

	process {
		$request = @{
			Session = $Session
		}

		if ($PSCmdlet.ParameterSetName -eq 'ById') {
			return Invoke-MmsApiRequest -Path ('/api/DeviceInformationV2/{0}' -f $ClientId) @request
		}

		$query = @{ type = $Type }
		if ($PSBoundParameters.ContainsKey('Limit')) {
			$query['limit'] = $Limit
		}
		if ($PSBoundParameters.ContainsKey('Offset')) {
			$query['offset'] = $Offset
		}

		return Invoke-MmsApiRequest -Path '/api/DeviceInformationV2' -Query $query @request
	}
}
