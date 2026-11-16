function Get-MmsApcPipelineVariable {
	<#
	.SYNOPSIS
		Returns the pipeline variables stored in the APC.
	.DESCRIPTION
		GET /api/apc/PipelineVariable/all   all variables
		GET /api/apc/PipelineVariable/{id}  one variable

		Only reading and deleting are part of the documented API. Creating and
		changing (POST/PUT on the same controller) are marked
		[ApiExplorerSettings(IgnoreApi = true)] in the server, so variables are
		maintained in the APC UI.
	.PARAMETER Id
		Variable id.
	.PARAMETER Key
		Filters by key (wildcards allowed, client side).
	.EXAMPLE
		Get-MmsApcPipelineVariable | Format-Table Key, Value, VariableType
	.EXAMPLE
		Get-MmsApcPipelineVariable -Key 'NetworkDrive*'
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Id,

		[Parameter(ParameterSetName = 'All')]
		[string]
		$Key,

		[Parameter()]
		[object]
		$Session
	)

	if ($PSCmdlet.ParameterSetName -eq 'ById') {
		return Invoke-MmsApiRequest -Path ('/api/apc/PipelineVariable/{0}' -f $Id) -Session $Session -Unwrap
	}

	$variables = Invoke-MmsApiRequest -Path '/api/apc/PipelineVariable/all' -Session $Session -Unwrap

	if ([string]::IsNullOrWhiteSpace($Key)) {
		return $variables
	}

	return $variables | Where-Object { $_.Key -like $Key }
}
