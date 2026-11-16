function Get-MmsApcEmpCleanupDirectorySize {
	<#
	.SYNOPSIS
		Returns the size of a package directory in bytes.
	.DESCRIPTION
		GET /api/apc/EmpirumCleanup/CalculateSize?directory=&tenantId=

		Useful to estimate how much space a cleanup would free. The server walks
		the directory, so the call can take a while on large shares.
	.PARAMETER Directory
		Directory as reported by Get-MmsApcEmpCleanupPackageList.
	.PARAMETER TenantId
		Tenant the directory belongs to.
	.EXAMPLE
		Get-MmsApcEmpCleanupDirectorySize -Directory $package.Directory -TenantId $tenantId
	#>
	[CmdletBinding()]
	[OutputType([long])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Directory,

		[Parameter(Mandatory = $true)]
		[guid]
		$TenantId,

		[Parameter()]
		[object]
		$Session
	)

	$query = @{
		directory = $Directory
		tenantId  = $TenantId
	}

	return Invoke-MmsApiRequest -Path '/api/apc/EmpirumCleanup/CalculateSize' -Query $query -Session $Session -Unwrap
}
