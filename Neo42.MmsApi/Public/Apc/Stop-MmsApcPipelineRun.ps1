function Stop-MmsApcPipelineRun {
	<#
	.SYNOPSIS
		Cancels a running pipeline run.
	.DESCRIPTION
		POST /api/apc/PipelineInteraction/cancel with { RunId }

		Returns true when the cancellation was accepted. Whatever the pipeline
		already did is not undone.
	.PARAMETER RunId
		Run id (guid) to cancel.
	.EXAMPLE
		Stop-MmsApcPipelineRun -RunId $runId -WhatIf
	.EXAMPLE
		Stop-MmsApcPipelineRun -RunId $runId -Confirm:$false
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[guid]
		$RunId,

		[Parameter()]
		[object]
		$Session
	)

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ('Pipeline run {0}' -f $RunId) -Action 'Cancel')) {
		return
	}

	return Invoke-MmsApiRequest -Path '/api/apc/PipelineInteraction/cancel' -Method POST -Body @{ RunId = [string]$RunId } -Session $Session -Confirm:$false
}
