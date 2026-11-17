<#
	Runs the -Confirm scenario of Test-MmsShouldProcess in a child process.

	This file is NOT dot-sourced. It is started as its own
	'powershell.exe -NonInteractive' by Unit\Test-MmsShouldProcess.Tests.ps1,
	and that is the whole point of it.

	The behaviour under test is a prompt: a calling script that asked for
	-Confirm must be prompted even though the inner call carries -Confirm:$false.
	A prompt cannot be asserted in the host that runs the suite - in a console it
	stops the run at '[Y] Yes [N] No' and waits for a human, and the default is
	Yes, so whoever presses Enter to get the run moving again accepts the
	deletion and turns the most dangerous path in the module green. A host that
	cannot prompt has no such ambiguity: ShouldContinue throws, and the request
	provably never goes out.

	So the child process is the observation instrument. -NonInteractive is passed
	explicitly, which makes the result independent of whether the suite itself
	was started from a console, a scheduled task or a CI agent.

	Prints two lines for the caller to assert on:

		THREW=yes|no
		MESSAGE=<exception message, whitespace collapsed>

	The message is what separates the two outcomes, and the separation was
	checked in both directions rather than assumed:

		asked   ->  Exception calling "ShouldContinue" ... NonInteractive mode
		acted   ->  MMS API call failed: DELETE https://unit.invalid/...

	An earlier version of this probe tried to shadow Invoke-RestMethod inside the
	module to observe 'did it act' directly. It silently did not work - a plain
	'function Invoke-RestMethod' inside a scriptblock lands in that scriptblock's
	own scope, not in the module's, so the flag it set never changed and the
	assertion built on it could not fail. It would have needed 'function
	script:Invoke-RestMethod'. The message above needs no such trick, so there is
	nothing left to get wrong.

	The address is unit.invalid, so 'acted' fails in DNS and no server is ever
	reached even if every guard in the module gives way at once.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[string]
	$Manifest
)

Import-Module -Name $Manifest -Force -ErrorAction Stop

# Stands in for a housekeeping script: SupportsShouldProcess, started with
# -Confirm by a user, and passing -Confirm:$false on the inner call the way an
# unattended script does.
function Invoke-CallingScript {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory = $true)]
		[scriptblock]
		$Body
	)
	& $Body
}

# '& $module { }' is the plain PowerShell stand-in for InModuleScope, which
# is not available in this child process.
$module = Get-Module -Name Neo42.MmsApi
$session = & $module { New-MmsApiSessionObject -ServerName 'https://unit.invalid' }

$body = { Remove-MmsClient -ClientId '11111111-1111-1111-1111-111111111111' -Session $session -Confirm:$false }

try {
	Invoke-CallingScript -Body $body -Confirm
	'THREW=no'
	'MESSAGE='
}
catch {
	'THREW=yes'
	'MESSAGE=' + ($_.Exception.Message -replace '\s+', ' ')
}
