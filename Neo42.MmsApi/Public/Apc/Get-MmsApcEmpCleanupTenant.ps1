function Get-MmsApcEmpCleanupTenant {
	<#
	.SYNOPSIS
		Returns APC tenants.
	.DESCRIPTION
		Documented routes of the group 'APC Plug-in - Tenants':
			GET /api/apc/tenant/all             all tenants
			GET /api/apc/tenant/{id}            one tenant by guid
			GET /api/apc/tenant?tenantName=...  one tenant by name

		The TenantId of a tenant is the input for every Empirum cleanup call.
		The name matches the function of the same name in the example scripts
		(ManagementService-PowerShell\API\APC\EmpirumCleanup), so those scripts
		can later import this module instead of carrying their own copy.
	.PARAMETER All
		All tenants (default).
	.PARAMETER TenantName
		Filter by tenant name.
	.PARAMETER TenantGuid
		Single tenant by guid.
	.EXAMPLE
		Get-MmsApcEmpCleanupTenant | Format-Table TenantId, TenantName
	.EXAMPLE
		Get-MmsApcEmpCleanupTenant -TenantName 'Default'
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'All')]
		[switch]
		$All,

		[Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$TenantName,

		[Parameter(ParameterSetName = 'ByGuid', Mandatory = $true)]
		[guid]
		$TenantGuid,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
		Unwrap            = $true
	}

	switch ($PSCmdlet.ParameterSetName) {
		'ByName' {
			return Invoke-MmsApiRequest -Path '/api/apc/tenant' -Query @{ tenantName = $TenantName } @request
		}
		'ByGuid' {
			return Invoke-MmsApiRequest -Path ('/api/apc/tenant/{0}' -f $TenantGuid) @request
		}
		default {
			return Invoke-MmsApiRequest -Path '/api/apc/tenant/all' @request
		}
	}
}
