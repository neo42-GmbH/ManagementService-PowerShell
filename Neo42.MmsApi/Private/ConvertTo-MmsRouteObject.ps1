function ConvertTo-MmsRouteObject {
	<#
	.SYNOPSIS
		Flattens a swagger 2.0 document into one object per operation.
	.DESCRIPTION
		Shared by Find-MmsApiRoute and Tools\Update-MmsApiCatalog.ps1 so that both
		describe routes identically.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[psobject]
		$SwaggerDocument
	)

	foreach ($path in $SwaggerDocument.paths.PSObject.Properties) {
		foreach ($method in $path.Value.PSObject.Properties) {
			$operation = $method.Value

			$parameters = @($operation.parameters | Where-Object { $_.name -ne 'X-Neo42-Auth' })
			$pathParameters = @($parameters | Where-Object { $_.in -eq 'path' } | ForEach-Object { $_.name })
			$queryParameters = @($parameters | Where-Object { $_.in -eq 'query' } | ForEach-Object { $_.name })
			$bodyParameter = @($parameters | Where-Object { $_.in -eq 'body' })

			$authHeader = @($operation.parameters | Where-Object { $_.name -eq 'X-Neo42-Auth' })

			[pscustomobject]@{
				Method          = $method.Name.ToUpperInvariant()
				Path            = $path.Name
				Tag             = ($operation.tags | Select-Object -First 1)
				OperationId     = $operation.operationId
				PathParameters  = $pathParameters
				QueryParameters = $queryParameters
				BodySchema      = (Get-MmsSchemaName -Schema (@($bodyParameter)[0].schema))
				ResponseSchema  = (Get-MmsSchemaName -Schema $operation.responses.'200'.schema)
				AuthHeader      = (@($authHeader)[0].default)
			}
		}
	}
}
