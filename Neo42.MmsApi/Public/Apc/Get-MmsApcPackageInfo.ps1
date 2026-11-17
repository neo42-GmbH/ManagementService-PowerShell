function Get-MmsApcPackageInfo {
	<#
	.SYNOPSIS
		Returns the packages known to the Application Package Center.
	.DESCRIPTION
		GET /api/apc/PackageInfo/all/{packageInfoType}/{showOnlyLatestVersion}/{cultureCode}
		GET /api/apc/PackageInfo/all/{packageInfoType}/{showOnlyLatestVersion}/{tenantId}/{bridgeType}/{cultureCode}

		Without -TenantId the simple list is returned (PackageInfo), with
		-TenantId and -BridgeType the variant including bridge version
		(PackageInfoAdvanced) - that is the one that shows what is already
		deployed into a deployment system.

		The numeric values behind the names are documented in the controller:
			PackageType: 0 all, 1 Depot, 2 Individual Packaging,
			             3 Packaged Tools, 4 Tools
			BridgeType:  1 Empirum, 2 Matrix42 Cloud, 3 Intune,
			             4 ConfigMgr, 5 WSO
	.PARAMETER PackageType
		Which packages to return, default 'All'.
	.PARAMETER LatestVersionOnly
		Only the newest version per package.
	.PARAMETER TenantId
		Tenant for the advanced variant (requires -BridgeType).
	.PARAMETER BridgeType
		Deployment system for the advanced variant (requires -TenantId).
	.PARAMETER CultureCode
		Language of the texts, 'en' or 'de'.
	.EXAMPLE
		Get-MmsApcPackageInfo -LatestVersionOnly | Format-Table Name, Version
	.EXAMPLE
		Get-MmsApcPackageInfo -PackageType Depot -TenantId $tenantId -BridgeType ConfigMgr -CultureCode de
	#>
	[CmdletBinding(DefaultParameterSetName = 'Simple')]
	[OutputType([pscustomobject])]
	param (
		[Parameter()]
		[ValidateSet('All', 'Depot', 'IndividualPackaging', 'PackagedTools', 'Tools')]
		[string]
		$PackageType = 'All',

		[Parameter()]
		[switch]
		$LatestVersionOnly,

		[Parameter(ParameterSetName = 'Advanced', Mandatory = $true)]
		[guid]
		$TenantId,

		[Parameter(ParameterSetName = 'Advanced', Mandatory = $true)]
		[ValidateSet('Empirum', 'Matrix42Cloud', 'Intune', 'ConfigMgr', 'Wso')]
		[string]
		$BridgeType,

		[Parameter()]
		[ValidateSet('en', 'de')]
		[string]
		$CultureCode = 'en',

		[Parameter()]
		[object]
		$Session
	)

	$packageTypeValue = @{
		All                 = 0
		Depot               = 1
		IndividualPackaging = 2
		PackagedTools       = 3
		Tools               = 4
	}[$PackageType]

	$latest = if ($LatestVersionOnly) { 'true' } else { 'false' }

	if ($PSCmdlet.ParameterSetName -eq 'Advanced') {
		$bridgeTypeValue = @{
			Empirum       = 1
			Matrix42Cloud = 2
			Intune        = 3
			ConfigMgr     = 4
			Wso           = 5
		}[$BridgeType]

		$path = '/api/apc/PackageInfo/all/{0}/{1}/{2}/{3}/{4}' -f $packageTypeValue, $latest, $TenantId, $bridgeTypeValue, $CultureCode
	}
	else {
		$path = '/api/apc/PackageInfo/all/{0}/{1}/{2}' -f $packageTypeValue, $latest, $CultureCode
	}

	return Invoke-MmsApiRequest -Path $path -Session $Session
}
