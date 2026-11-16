function Set-MmsFilter {
	<#
	.SYNOPSIS
		Writes an MMS filter back to the criteria store.
	.DESCRIPTION
		Wraps the documented route
			POST /api/criteriastorev3

		The server takes the whole filter object, so the way to change one is:
		read it with Get-MmsFilter, change it, hand it back here. Only pass
		objects that came from Get-MmsFilter - a hand built one is missing
		properties the server expects.

		If -Criteria is given, it replaces the Criteria property and is serialized
		to the compact json string the server stores. That is the usual case:
		everything a user cares about lives inside Criteria.

		This changes what the MMS considers a member of a dynamic computer group.
		Run it with -WhatIf first.
	.PARAMETER Filter
		The filter object from Get-MmsFilter, including its Id and Type.
	.PARAMETER Criteria
		New criteria as an object. Replaces Filter.Criteria after being converted
		to json. Without it the Criteria of -Filter is sent unchanged.
	.EXAMPLE
		$filter = Get-MmsFilter -Name 'All notebooks'
		$criteria = $filter.CriteriaObject
		$criteria.Data.ComputernameList = @('PC0815', 'PC0816')
		Set-MmsFilter -Filter $filter -Criteria $criteria -WhatIf
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		[object]
		$Filter,

		[Parameter(Position = 1)]
		[object]
		$Criteria,

		[Parameter()]
		[object]
		$Session
	)

	process {
		if ($null -eq $Filter.Id) {
			throw 'The object passed to -Filter has no Id. Read the filter with Get-MmsFilter and pass that object.'
		}

		# CriteriaObject is added by Get-MmsFilter -ExpandCriteria and is not part
		# of the server model, so it must not be sent back.
		$body = $Filter | Select-Object -Property * -ExcludeProperty CriteriaObject

		if ($PSBoundParameters.ContainsKey('Criteria')) {
			$body.Criteria = ConvertTo-Json -InputObject $Criteria -Depth 20 -Compress
		}

		$name = $Filter.CriteriaObject.Name
		if ([string]::IsNullOrWhiteSpace($name)) {
			$name = $Filter.Id
		}

		if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target "filter '$name'" -Action 'Overwrite the filter in the MMS criteria store')) {
			return
		}

		$null = Invoke-MmsApiRequest -Path '/api/criteriastorev3' -Method POST -Body $body `
			-Session $Session -Confirm:$false
	}
}
