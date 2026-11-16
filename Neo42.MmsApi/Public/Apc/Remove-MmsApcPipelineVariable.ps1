function Remove-MmsApcPipelineVariable {
	<#
	.SYNOPSIS
		Deletes a pipeline variable.
	.DESCRIPTION
		DELETE /api/apc/PipelineVariable/{id}

		Careful: a variable that a pipeline still references is missing
		afterwards, and the run fails with InvalidRequiredVariable. Creating it
		again is only possible in the APC UI, since POST/PUT are not part of the
		documented API.
	.PARAMETER Id
		Variable id to delete.
	.EXAMPLE
		Remove-MmsApcPipelineVariable -Id $variableId -WhatIf
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Id,

		[Parameter()]
		[object]
		$Session
	)

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target ('Pipeline variable {0}' -f $Id) -Action 'Delete')) {
		return
	}

	return Invoke-MmsApiRequest -Path ('/api/apc/PipelineVariable/{0}' -f $Id) -Method DELETE -Session $Session -Confirm:$false -Unwrap
}
