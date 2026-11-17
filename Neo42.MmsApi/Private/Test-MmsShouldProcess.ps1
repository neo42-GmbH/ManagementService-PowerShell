function Test-MmsShouldProcess {
	<#
	.SYNOPSIS
		ShouldProcess that also honours -WhatIf and -Confirm of a calling script.
	.DESCRIPTION
		A function exported from a module runs in the module scope and therefore
		does NOT inherit $WhatIfPreference or $ConfirmPreference from the script
		that calls it. Both directions of that gap are dangerous:

		- A script with [CmdletBinding(SupportsShouldProcess)] started with
		  -WhatIf would silently perform real deletions inside this module.
		- A script that passes -Confirm:$false on an inner call (the right thing
		  for a scheduled task) would swallow a -Confirm that the user asked for
		  on the script itself.

		The caller preferences are still reachable: $PSCmdlet.SessionState of a
		module function points at the session state of the caller, not at the
		module. This function reads them from there.

		Use it instead of $PSCmdlet.ShouldProcess in every function that changes
		something on the server.

		Note: the 'What if:' line goes to the host, the same way PowerShell's own
		ShouldProcess reports it. It is meant to be read, not captured.
	.PARAMETER Cmdlet
		Always $PSCmdlet of the calling public function.
	.PARAMETER Target
		What is being changed, for example 'client CLIENT2'.
	.PARAMETER Action
		What is being done to it, for example 'Delete'.
	.OUTPUTS
		Boolean. $true only when the operation may really be performed.
	#>
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.PSCmdlet]
		$Cmdlet,

		[Parameter(Mandatory = $true)]
		[string]
		$Target,

		[Parameter(Mandatory = $true)]
		[string]
		$Action
	)

	$bound = $Cmdlet.MyInvocation.BoundParameters

	# -WhatIf: an explicit switch on this call wins, otherwise take the caller's.
	if ($bound.ContainsKey('WhatIf')) {
		$whatIf = [bool]$bound['WhatIf']
	}
	else {
		$whatIf = ($true -eq $Cmdlet.SessionState.PSVariable.GetValue('WhatIfPreference'))
	}

	if ($whatIf) {
		Write-Host ('What if: Performing the operation "{0}" on target "{1}".' -f $Action, $Target)
		return $false
	}

	# -Confirm: a caller that lowered its ConfirmPreference asked for prompts
	# ('Low' is what -Confirm sets). That request outranks a -Confirm:$false that
	# a wrapper put on this call for unattended use, so prompt explicitly -
	# ShouldProcess would return $true without asking.
	if ($bound.ContainsKey('Confirm') -and -not ([bool]$bound['Confirm'])) {
		$callerConfirm = $Cmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
		if ($callerConfirm -is [System.Management.Automation.ConfirmImpact] -and
			$callerConfirm -eq [System.Management.Automation.ConfirmImpact]::Low) {
			$query = 'Performing the operation "{0}" on target "{1}".' -f $Action, $Target
			return $Cmdlet.ShouldContinue($query, 'Confirm')
		}
	}

	return $Cmdlet.ShouldProcess($Target, $Action)
}
