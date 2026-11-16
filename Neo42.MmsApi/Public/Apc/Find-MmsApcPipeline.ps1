function Find-MmsApcPipeline {
	<#
	.SYNOPSIS
		Searches pipelines by tags and required phase variables.
	.DESCRIPTION
		POST /api/apc/PipelineSpecificationItem/Filtered with
		{ Tags, ExcludedTags, RequiredPhaseVariables, LanguageKey }

		A POST that only queries. Unlike Get-MmsApcPipeline it returns the full
		PipelineSpecificationItem (pipeline plus its PhaseSpecificationItem), and
		it filters server side - useful when a pipeline should be picked by tag
		instead of by name.

		Because the route is a POST it goes through ShouldProcess: with -WhatIf
		the query is not sent and nothing is returned.
	.PARAMETER Tag
		Tags a pipeline must carry.
	.PARAMETER ExcludedTag
		Tags that exclude a pipeline.
	.PARAMETER RequiredPhaseVariable
		Keys of phase variables the pipeline must offer, for example
		'NetworkDriveId'.
	.PARAMETER LanguageKey
		Language of the returned texts, for example 'en' or 'de'.
	.EXAMPLE
		Find-MmsApcPipeline -Tag 'ConfigMgr'
	.EXAMPLE
		Find-MmsApcPipeline -RequiredPhaseVariable 'NetworkDriveId', 'NetworkDriveFilePath'
	#>
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([pscustomobject])]
	param (
		[Parameter()]
		[string[]]
		$Tag,

		[Parameter()]
		[string[]]
		$ExcludedTag,

		[Parameter()]
		[string[]]
		$RequiredPhaseVariable,

		[Parameter()]
		[string]
		$LanguageKey = 'en',

		[Parameter()]
		[object]
		$Session
	)

	$body = @{
		LanguageKey            = $LanguageKey
		Tags                   = @(foreach ($value in $Tag) { @{ Name = $value } })
		ExcludedTags           = @(foreach ($value in $ExcludedTag) { @{ Name = $value } })
		RequiredPhaseVariables = @(foreach ($value in $RequiredPhaseVariable) { @{ Key = $value } })
	}

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target 'the APC pipeline list' -Action 'Query the pipelines matching the given tags')) {
		return
	}

	return Invoke-MmsApiRequest -Path '/api/apc/PipelineSpecificationItem/Filtered' -Method POST -Body $body -Session $Session -Unwrap -Confirm:$false
}
