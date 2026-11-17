function Wait-MmsApcPipelineRun {
	<#
	.SYNOPSIS
		Waits until a pipeline run has finished and returns it.
	.DESCRIPTION
		Polls GET /api/apc/PipelineRun/{id} until EndTime is set or the timeout is
		reached. Same pattern as the official example
		ManagementService-PowerShell\API\APC\Invoke-PipelineWithVariables.ps1,
		but as a reusable function.

		On timeout the function writes a non terminating error and returns the
		last state it saw, so a caller can decide what to do (the run keeps
		going on the server; Stop-MmsApcPipelineRun cancels it).

		A run id that does not exist throws instead of waiting for the timeout:
		the server answers such a request with HTTP 200 and an empty body.
	.PARAMETER RunId
		Run id (guid) from Start-MmsApcPipeline.
	.PARAMETER TimeoutMinutes
		How long to wait, default 10 minutes.
	.PARAMETER PollSeconds
		Interval between two checks, default 5 seconds.
	.EXAMPLE
		$run = Wait-MmsApcPipelineRun -RunId $runId
		$run.StateName
	.EXAMPLE
		Wait-MmsApcPipelineRun -RunId $runId -TimeoutMinutes 30 -PollSeconds 10 -Verbose
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[guid]
		$RunId,

		[Parameter()]
		[ValidateRange(1, 1440)]
		[int]
		$TimeoutMinutes = 10,

		[Parameter()]
		[ValidateRange(1, 300)]
		[int]
		$PollSeconds = 5,

		[Parameter()]
		[object]
		$Session
	)

	$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
	$run = $null
	$notFoundCount = 0

	while ((Get-Date) -lt $deadline) {
		$run = Get-MmsApcPipelineRun -RunId $RunId -Session $Session

		if ($null -eq $run) {
			# The server answers an unknown run id with HTTP 200 and an empty body,
			# so waiting for it would run into the timeout. Allow one miss for the
			# moment right after enqueuing, then fail fast.
			$notFoundCount++
			if ($notFoundCount -gt 1) {
				throw ('Pipeline run {0} does not exist on the server.' -f $RunId)
			}
			Write-Verbose ('Run {0} not visible yet, retrying in {1}s.' -f $RunId, $PollSeconds)
			Start-Sleep -Seconds $PollSeconds
			continue
		}

		$notFoundCount = 0

		if ($null -ne $run.EndTime) {
			Write-Verbose ('Run {0} finished with state {1}.' -f $RunId, $run.StateName)
			return $run
		}

		Write-Verbose ('Run {0} is in state {1}, waiting {2}s.' -f $RunId, $run.StateName, $PollSeconds)
		Start-Sleep -Seconds $PollSeconds
	}

	Write-Error ('Pipeline run {0} did not finish within {1} minute(s). Last state: {2}.' -f $RunId, $TimeoutMinutes, $run.StateName)
	return $run
}
