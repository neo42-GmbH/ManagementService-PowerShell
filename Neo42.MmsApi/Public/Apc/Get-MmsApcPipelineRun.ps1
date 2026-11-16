function Get-MmsApcPipelineRun {
	<#
	.SYNOPSIS
		Returns pipeline runs.
	.DESCRIPTION
		GET /api/apc/PipelineRun/{id}                one run by run id (guid)
		GET /api/apc/PipelineRun/GetMany/{pipelineId} all runs of a pipeline

		The numeric State is kept as delivered; the readable name is added as the
		extra property StateName. A run is finished as soon as EndTime is set.

		An unknown run id is answered by the server with HTTP 200 and an empty
		body (not a 404); this function then returns nothing.
	.PARAMETER RunId
		Run id (guid), as returned by Start-MmsApcPipeline.
	.PARAMETER PipelineId
		Pipeline id (24 character ObjectId) whose runs should be listed.
	.EXAMPLE
		Get-MmsApcPipelineRun -RunId $runId | Format-List Name, StateName, StartTime, EndTime
	.EXAMPLE
		Get-MmsApcPipelineRun -PipelineId '68beac8e39371af64995df0e' | Sort-Object StartTime -Descending | Select-Object -First 5
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ByRun', Mandatory = $true, Position = 0)]
		[guid]
		$RunId,

		[Parameter(ParameterSetName = 'ByPipeline', Mandatory = $true)]
		[ValidatePattern('^[0-9a-fA-F]{24}$')]
		[string]
		$PipelineId,

		[Parameter()]
		[object]
		$Session
	)

	$path = if ($PSCmdlet.ParameterSetName -eq 'ByRun') {
		'/api/apc/PipelineRun/{0}' -f $RunId
	}
	else {
		'/api/apc/PipelineRun/GetMany/{0}' -f $PipelineId
	}

	$runs = Invoke-MmsApiRequest -Path $path -Session $Session

	foreach ($run in $runs) {
		# An unknown run id is answered with HTTP 200 and an empty body, which
		# deserializes to an empty string. Emit nothing in that case.
		if ($null -eq $run -or $run -is [string]) {
			continue
		}
		$run | Add-Member -NotePropertyName 'StateName' -NotePropertyValue (Get-MmsApcPipelineRunStateName -State $run.State) -Force
		$run
	}
}
