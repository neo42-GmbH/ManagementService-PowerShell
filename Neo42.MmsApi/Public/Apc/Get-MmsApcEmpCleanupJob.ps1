function Get-MmsApcEmpCleanupJob {
	<#
	.SYNOPSIS
		Returns Empirum cleanup jobs.
	.DESCRIPTION
		GET /api/apc/EmpirumCleanupJob/{id}           one job
		GET /api/apc/EmpirumCleanupJob/all?tenantId=  all jobs of a tenant
	.PARAMETER JobId
		Single job by id.
	.PARAMETER TenantId
		Tenant whose jobs should be listed.
	.EXAMPLE
		Get-MmsApcEmpCleanupJob -TenantId $tenantId
	.EXAMPLE
		Get-MmsApcEmpCleanupJob -JobId $jobId
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true)]
		[guid]
		$JobId,

		[Parameter(ParameterSetName = 'All', Mandatory = $true)]
		[guid]
		$TenantId,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
		Unwrap            = $true
	}

	if ($PSCmdlet.ParameterSetName -eq 'ById') {
		return Invoke-MmsApiRequest -Path ('/api/apc/EmpirumCleanupJob/{0}' -f $JobId) @request
	}

	return Invoke-MmsApiRequest -Path '/api/apc/EmpirumCleanupJob/all' -Query @{ tenantId = $TenantId } @request
}
