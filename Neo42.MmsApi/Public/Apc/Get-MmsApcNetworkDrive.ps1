function Get-MmsApcNetworkDrive {
	<#
	.SYNOPSIS
		Returns the network drives (file scanner) of the APC.
	.DESCRIPTION
		GET /api/apc/NetworkDrive/all            all drives
		GET /api/apc/NetworkDrive/{id}           one drive
		GET /api/apc/NetworkDrive?tenantId=      drives of a tenant
		GET /api/apc/NetworkDrive/exists?id=     existence check

		The drive id is the value that pipelines expect as phase variable
		NetworkDriveId.
	.PARAMETER Id
		Drive id (guid).
	.PARAMETER TenantId
		Only the drives of this tenant.
	.PARAMETER Exists
		Together with -Id: returns only true/false instead of the object.
	.EXAMPLE
		Get-MmsApcNetworkDrive | Format-Table Id, Name, Path
	.EXAMPLE
		Get-MmsApcNetworkDrive -TenantId $tenantId
	.EXAMPLE
		Get-MmsApcNetworkDrive -Id $driveId -Exists
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0)]
		[guid]
		$Id,

		[Parameter(ParameterSetName = 'ByTenant', Mandatory = $true)]
		[guid]
		$TenantId,

		[Parameter(ParameterSetName = 'ById')]
		[switch]
		$Exists,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
		Unwrap            = $true
	}

	switch ($PSCmdlet.ParameterSetName) {
		'ById' {
			if ($Exists) {
				return Invoke-MmsApiRequest -Path '/api/apc/NetworkDrive/exists' -Query @{ id = $Id } @request
			}
			return Invoke-MmsApiRequest -Path ('/api/apc/NetworkDrive/{0}' -f $Id) @request
		}
		'ByTenant' {
			return Invoke-MmsApiRequest -Path '/api/apc/NetworkDrive' -Query @{ tenantId = $TenantId } @request
		}
		default {
			return Invoke-MmsApiRequest -Path '/api/apc/NetworkDrive/all' @request
		}
	}
}
