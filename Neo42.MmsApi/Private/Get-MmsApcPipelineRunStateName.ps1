function Get-MmsApcPipelineRunStateName {
	<#
	.SYNOPSIS
		Translates the numeric State of a pipeline run into its name.
	.DESCRIPTION
		The API answers with the numeric value (swagger: enum 0..10). The names
		are taken from the official example script
		ManagementService-PowerShell\API\APC\Invoke-PipelineWithVariables.ps1
		and from PipelineRunState in the server sources.

		An unknown value is returned as 'Unknown (<n>)' instead of $null, so a new
		state in a future MMS version stays visible.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter()]
		[psobject]
		$State
	)

	if ($null -eq $State) {
		return $null
	}

	$names = @{
		0  = 'None'
		1  = 'Queued'
		2  = 'Started'
		3  = 'Running'
		4  = 'Canceled'
		5  = 'FinishedSuccessfully'
		6  = 'FinishedWithTimeout'
		7  = 'FinishedWithError'
		8  = 'PipelineNotFound'
		9  = 'InvalidRequiredVariable'
		10 = 'SuccessfullyNotCompleted'
	}

	$value = [int]$State
	if ($names.ContainsKey($value)) {
		return $names[$value]
	}

	return ('Unknown ({0})' -f $value)
}
