function Find-MmsApiRoute {
	<#
	.SYNOPSIS
		Searches the documented API surface of the MMS server.
	.DESCRIPTION
		Works on the local swagger snapshot (docs\swagger-v1.json), so it needs no
		network access and returns only routes that are released for automation.
		Routes that do not show up here may change or disappear in any MMS
		release without notice.

		Refresh the snapshot with Tools\Update-MmsApiCatalog.ps1.
	.PARAMETER Pattern
		Regular expression matched against path, operation id and tag.
	.PARAMETER Tag
		Restricts the result to a documentation group, for example 'BitLocker*'.
	.PARAMETER Method
		Restricts the result to one HTTP method.
	.PARAMETER WriteOnly
		Only routes that change data (everything except GET).
	.EXAMPLE
		Find-MmsApiRoute -Pattern 'bitlocker'
	.EXAMPLE
		Find-MmsApiRoute -Tag 'Clients'
	.EXAMPLE
		Find-MmsApiRoute -WriteOnly | Format-Table Method, Path, BodySchema
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Position = 0)]
		[string]
		$Pattern,

		[Parameter()]
		[string]
		$Tag,

		[Parameter()]
		[ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
		[string]
		$Method,

		[Parameter()]
		[switch]
		$WriteOnly
	)

	$routes = ConvertTo-MmsRouteObject -SwaggerDocument (Get-MmsSwaggerDocument)

	if (-not [string]::IsNullOrWhiteSpace($Pattern)) {
		$routes = $routes | Where-Object {
			$_.Path -match $Pattern -or $_.OperationId -match $Pattern -or $_.Tag -match $Pattern
		}
	}
	if (-not [string]::IsNullOrWhiteSpace($Tag)) {
		$routes = $routes | Where-Object { $_.Tag -like $Tag }
	}
	if (-not [string]::IsNullOrWhiteSpace($Method)) {
		$routes = $routes | Where-Object { $_.Method -eq $Method }
	}
	if ($WriteOnly) {
		$routes = $routes | Where-Object { $_.Method -ne 'GET' }
	}

	return $routes | Sort-Object -Property Tag, Path, Method
}
