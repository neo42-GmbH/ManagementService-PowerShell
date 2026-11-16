function Get-MmsApcDefaultPackage {
	<#
	.SYNOPSIS
		Returns the default packages of the APC.
	.DESCRIPTION
		GET /api/apc/DefaultPackage/all/{kind}

		Kind is documented in the controller as 0 = Package, 1 = Packaged tool.
	.PARAMETER Kind
		'Package' (0) or 'PackagedTool' (1).
	.EXAMPLE
		Get-MmsApcDefaultPackage
	.EXAMPLE
		Get-MmsApcDefaultPackage -Kind PackagedTool
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Position = 0)]
		[ValidateSet('Package', 'PackagedTool')]
		[string]
		$Kind = 'Package',

		[Parameter()]
		[object]
		$Session
	)

	$kindValue = @{ Package = 0; PackagedTool = 1 }[$Kind]

	return Invoke-MmsApiRequest -Path ('/api/apc/DefaultPackage/all/{0}' -f $kindValue) -Session $Session
}
