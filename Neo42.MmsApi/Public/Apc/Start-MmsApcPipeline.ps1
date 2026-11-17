function Start-MmsApcPipeline {
	<#
	.SYNOPSIS
		Triggers a pipeline run and returns its run id.
	.DESCRIPTION
		POST /api/apc/PipelineInteraction/run with { PipelineId, Variables }

		Additional phase variables are merged with the ones defined in the
		pipeline; a variable that the pipeline does not define is rejected by the
		server (state InvalidRequiredVariable).

		This starts real work (package import, deployment, ...), so ConfirmImpact
		is High: PowerShell asks before the request goes out. Use -WhatIf to see
		the exact body, -Confirm:$false for unattended runs.

		Requirement from the official example: the triggering Windows user must be
		a member of the local group 'Neo42MgmtSvcAdmins' on the MMS server (the
		route additionally requires the policy TRIGGER_PIPELINE).
	.PARAMETER PipelineId
		Pipeline id (24 character ObjectId), see Get-MmsApcPipeline.
	.PARAMETER Variables
		Phase variables as a hashtable, for example
		@{ NetworkDriveId = $driveId; NetworkDriveFilePath = '\\server\share\setup.exe' }
	.EXAMPLE
		Start-MmsApcPipeline -PipelineId '68beac8e39371af64995df0e' -WhatIf
	.EXAMPLE
		$runId = Start-MmsApcPipeline -PipelineId $id -Variables @{ NetworkDriveId = $driveId } -Confirm:$false
		Wait-MmsApcPipelineRun -RunId $runId
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	[OutputType([guid])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidatePattern('^[0-9a-fA-F]{24}$')]
		[string]
		$PipelineId,

		[Parameter(Position = 1)]
		[hashtable]
		$Variables,

		[Parameter()]
		[object]
		$Session
	)

	$body = @{
		PipelineId = $PipelineId
	}
	if ($null -ne $Variables -and $Variables.Count -gt 0) {
		$body['Variables'] = $Variables
	}

	$variableInfo = if ($null -ne $Variables -and $Variables.Count -gt 0) {
		' with variables: ' + (($Variables.Keys | Sort-Object) -join ', ')
	}
	else {
		''
	}

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ('Pipeline {0}' -f $PipelineId) -Action ('Trigger run' + $variableInfo))) {
		return
	}

	return Invoke-MmsApiRequest -Path '/api/apc/PipelineInteraction/run' -Method POST -Body $body -Session $Session -Confirm:$false
}
