function Get-MmsClient {
	<#
	.SYNOPSIS
		Returns the clients known to the MMS server.
	.DESCRIPTION
		Wraps the documented routes of the 'Clients' group:
			GET /api/Client                      all clients
			GET /api/Client/{id}                 one client by MMS id
			GET /api/client/{domain}/{name}      one client by domain and name

		The client id is the join key for nearly every report endpoint
		(Bitlocker, Device Information, Service Infrastructure, WSUS, ...).
	.PARAMETER Id
		MMS client id (guid).
	.PARAMETER Domain
		Domain of the client, used together with -Name.
	.PARAMETER Name
		Short computer name (property Name, for example CLIENT2), used together with
		-Domain. Not the NetBiosName property, which contains DOMAIN\NAME.
	.EXAMPLE
		Get-MmsClient
	.EXAMPLE
		Get-MmsClient -Domain 'corp.example.com' -Name 'PC0815'
	.EXAMPLE
		Get-MmsClient -Id '0082d481-1084-4494-bc1d-222b6df976f7'
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0)]
		[guid]
		$Id,

		[Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Domain,

		[Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Name,

		[Parameter()]
		[object]
		$Session
	)

	switch ($PSCmdlet.ParameterSetName) {
		'ById' {
			$path = '/api/Client/{0}' -f $Id
		}
		'ByName' {
			$path = '/api/client/{0}/{1}' -f [System.Uri]::EscapeDataString($Domain), [System.Uri]::EscapeDataString($Name)
		}
		default {
			$path = '/api/Client'
		}
	}

	return Invoke-MmsApiRequest -Path $path -Session $Session
}
