function Get-MmsApcPipeline {
	<#
	.SYNOPSIS
		Returns the pipelines of the Application Package Center.
	.DESCRIPTION
		GET /api/apc/Pipelines       all pipelines
		GET /api/apc/Pipelines/{id}  one pipeline

		Both routes answer with a PhaseSpecificationItem: the phase of the
		pipeline including its TaskSpecificationItems and its Variables. The
		Variables are what -Variables of Start-MmsApcPipeline can override.

		The pipeline id is a 24 character MongoDB ObjectId (not a guid). It is
		also visible in the URL when the pipeline is opened in the APC UI.

		Creating or changing a pipeline is not possible through the released API:
		POST /api/apc/PipelineSpecificationItem exists but is marked
		[ApiExplorerSettings(IgnoreApi = true)] in the server, so it is not part
		of the documented surface. Build pipelines in the APC UI.
	.PARAMETER Id
		Pipeline id (24 character ObjectId).
	.PARAMETER Name
		Filters the returned pipelines by name (wildcards allowed, client side).
	.EXAMPLE
		Get-MmsApcPipeline | Format-Table Id, Name, Enabled
	.EXAMPLE
		Get-MmsApcPipeline -Name '*ConfigMgr*'
	.EXAMPLE
		(Get-MmsApcPipeline -Id '68beac8e39371af64995df0e').Variables | Format-Table Key, Value, VariableRequired
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0)]
		[ValidatePattern('^[0-9a-fA-F]{24}$')]
		[string]
		$Id,

		[Parameter(ParameterSetName = 'All')]
		[string]
		$Name,

		[Parameter()]
		[object]
		$Session
	)

	if ($PSCmdlet.ParameterSetName -eq 'ById') {
		return Invoke-MmsApiRequest -Path ('/api/apc/Pipelines/{0}' -f $Id) -Session $Session
	}

	$pipelines = Invoke-MmsApiRequest -Path '/api/apc/Pipelines' -Session $Session

	if ([string]::IsNullOrWhiteSpace($Name)) {
		return $pipelines
	}

	return $pipelines | Where-Object { $_.Name -like $Name }
}
