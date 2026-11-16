function Get-MmsFilter {
	<#
	.SYNOPSIS
		Returns the MMS filters (criteria store).
	.DESCRIPTION
		Wraps the documented routes of the 'MMS Filter' group:
			GET /api/criteriastorev3        all filters
			GET /api/criteriastorev3/{id}   one filter

		A filter is what the MMS uses to build dynamic computer groups. Its
		definition sits in the Criteria property as a json string, so the readable
		name of a filter is $filter.Criteria | ConvertFrom-Json | Select Name.
		-ExpandCriteria does that and adds the result as CriteriaObject.

		The numeric Type says what kind of filter it is, for example 3 for
		ComputernameList.
	.PARAMETER Id
		Id of the filter.
	.PARAMETER Name
		Name of the filter, taken from the parsed Criteria. Implies
		-ExpandCriteria and returns nothing when no filter matches.
	.PARAMETER ExpandCriteria
		Parses the Criteria json and adds it as the CriteriaObject property.
	.EXAMPLE
		Get-MmsFilter -ExpandCriteria | Select-Object Id, Type, @{ n = 'Name'; e = { $_.CriteriaObject.Name } }
	.EXAMPLE
		Get-MmsFilter -Name 'All notebooks'
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0)]
		[guid]
		$Id,

		[Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Name,

		[Parameter()]
		[switch]
		$ExpandCriteria,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
	}

	$path = if ($PSCmdlet.ParameterSetName -eq 'ById') {
		'/api/criteriastorev3/{0}' -f $Id
	}
	else {
		'/api/criteriastorev3'
	}

	$filters = @(Invoke-MmsApiRequest -Path $path @request)

	if (-not ($ExpandCriteria -or $PSCmdlet.ParameterSetName -eq 'ByName')) {
		return $filters
	}

	$expanded = foreach ($filter in $filters) {
		$criteriaObject = $null
		if (-not [string]::IsNullOrWhiteSpace($filter.Criteria)) {
			try {
				$criteriaObject = $filter.Criteria | ConvertFrom-Json
			}
			catch {
				Write-Warning "Could not parse the Criteria of filter '$($filter.Id)': $($_.Exception.Message)"
			}
		}
		$filter | Add-Member -NotePropertyName 'CriteriaObject' -NotePropertyValue $criteriaObject -Force -PassThru
	}

	if ($PSCmdlet.ParameterSetName -eq 'ByName') {
		return @($expanded | Where-Object { $_.CriteriaObject.Name -eq $Name })
	}

	return $expanded
}
