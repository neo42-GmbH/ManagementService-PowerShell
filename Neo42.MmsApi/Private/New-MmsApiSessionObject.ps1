function New-MmsApiSessionObject {
	<#
	.SYNOPSIS
		Builds the session object that carries server and authentication.
	.DESCRIPTION
		Internal factory so that every place which produces a session (an explicit
		Connect-MmsApi, the default profile, the probe in Test-MmsApiConnection)
		produces the exact same shape. The type name allows Update-TypeData style
		formatting and a cheap sanity check with -is.
	.OUTPUTS
		PSCustomObject with the type name Neo42.MmsApi.Session.
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$ServerName,

		[Parameter()]
		[string]
		$ProfileName,

		[Parameter()]
		[ValidateSet('Windows', 'Credential')]
		[string]
		$AuthMode = 'Windows',

		[Parameter()]
		[AllowNull()]
		[pscredential]
		$Credential,

		[Parameter()]
		[string]
		$Source = 'Parameter',

		[Parameter()]
		[AllowNull()]
		[string]
		$ServerVersion
	)

	$user = switch ($AuthMode) {
		'Credential' {
			$Credential.UserName
		}
		default {
			'{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME
		}
	}

	return [pscustomobject]@{
		PSTypeName    = 'Neo42.MmsApi.Session'
		ServerName    = $ServerName
		ProfileName   = $ProfileName
		AuthMode      = $AuthMode
		User          = $user
		Credential    = $Credential
		ServerVersion = $ServerVersion
		Source        = $Source
		ConnectedAt   = (Get-Date)
	}
}
