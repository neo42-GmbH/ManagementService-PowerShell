function Get-MmsWsusComputerTarget {
	<#
	.SYNOPSIS
		Returns the WSUS computer targets known to the MMS.
	.DESCRIPTION
		Wraps the documented routes of the 'WSUS Plug-in - Computer' group:
			GET /api/WsusComputerTargetV2                      all targets
			GET /api/WsusComputerTargetV2/{id}                 one target by id
			GET /api/WsusComputerTargetV2/{id}?netBiosName=    one target by name

		A computer target is the WSUS side of a client. Its FullDomainName is the
		key that Get-MmsWsusUpdateSummary expects, so the usual order is: client
		-> computer target -> update summary.

		The lookup by name uses the empty guid as the path id, which is how the
		server route is built.
	.PARAMETER Id
		Id of the computer target.
	.PARAMETER NetBiosName
		Name of the client as WSUS knows it, in the form 'DOMAIN\CLIENT'.
	.EXAMPLE
		Get-MmsWsusComputerTarget
	.EXAMPLE
		Get-MmsWsusComputerTarget -NetBiosName 'CORP\PC0815'
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0)]
		[guid]
		$Id,

		[Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]
		$NetBiosName,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
	}

	switch ($PSCmdlet.ParameterSetName) {
		'ById' {
			return Invoke-MmsApiRequest -Path ('/api/WsusComputerTargetV2/{0}' -f $Id) @request
		}
		'ByName' {
			$path = '/api/WsusComputerTargetV2/{0}' -f [System.Guid]::Empty
			return Invoke-MmsApiRequest -Path $path -Query @{ netBiosName = $NetBiosName } @request
		}
		default {
			return Invoke-MmsApiRequest -Path '/api/WsusComputerTargetV2' @request
		}
	}
}
