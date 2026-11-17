function ConvertTo-MmsCleanupActionValue {
	<#
	.SYNOPSIS
		Maps an Empirum cleanup action name to the numeric API value.
	.DESCRIPTION
		The API expects an int. The names match the enum used by the example
		scripts, so calls written against those scripts keep working:
			NoAssignmentInstallApproved   = 1
			NoAssignmentNoInstallApproved = 2
			AllPackages                   = 3

		Deliberately not implemented as an Add-Type enum: a type added that way
		cannot be unloaded and would occupy the very generic name 'CleanupAction'
		for the whole AppDomain.
	#>
	[CmdletBinding()]
	[OutputType([int])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('NoAssignmentInstallApproved', 'NoAssignmentNoInstallApproved', 'AllPackages')]
		[string]
		$Action
	)

	switch ($Action) {
		'NoAssignmentInstallApproved' { return 1 }
		'NoAssignmentNoInstallApproved' { return 2 }
		'AllPackages' { return 3 }
	}
}
