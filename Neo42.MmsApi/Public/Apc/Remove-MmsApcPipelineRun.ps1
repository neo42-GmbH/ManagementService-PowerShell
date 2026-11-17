function Remove-MmsApcPipelineRun {
	<#
	.SYNOPSIS
		Deletes a pipeline run from the history.
	.DESCRIPTION
		DELETE /api/apc/PipelineRun/{id}

		Removes the run entry including its protocol. Used for housekeeping, see
		ManagementService-PowerShell\API\Housekeeping\Pipeline-Runs-Housekeeping.ps1.
	.PARAMETER RunId
		Run id (guid) to delete.
	.EXAMPLE
		Remove-MmsApcPipelineRun -RunId $runId -WhatIf
	.EXAMPLE
		Get-MmsApcPipelineRun -PipelineId $id | Where-Object { $_.EndTime -and [datetime]$_.EndTime -lt (Get-Date).AddDays(-90) } | ForEach-Object { Remove-MmsApcPipelineRun -RunId $_.RunId -Confirm:$false }
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
		[guid]
		$RunId,

		[Parameter()]
		[object]
		$Session
	)

	process {
		if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ('Pipeline run {0}' -f $RunId) -Action 'Delete')) {
			return
		}

		Invoke-MmsApiRequest -Path ('/api/apc/PipelineRun/{0}' -f $RunId) -Method DELETE -Session $Session -Confirm:$false
	}
}
