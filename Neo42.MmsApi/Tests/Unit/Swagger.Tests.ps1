<#
	The helpers that read the swagger snapshot.

	Small, pure and offline. They are worth their own file because everything
	else that reasons about the API surface builds on them: the route check that
	warns about undocumented calls, and the catalog generator.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest
}

Describe 'Test-MmsDocumentedRoute' -Tag 'Unit' {
	It 'accepts a concrete guid where the template has a placeholder' {
		InModuleScope Neo42.MmsApi {
			Test-MmsDocumentedRoute -Method 'GET' -Path '/api/Client/0082d481-1084-4494-bc1d-222b6df976f7'
		} | Should -BeTrue
	}

	It 'accepts a two segment template' {
		InModuleScope Neo42.MmsApi {
			Test-MmsDocumentedRoute -Method 'GET' -Path '/api/client/example.com/PC0815'
		} | Should -BeTrue
	}

	It 'ignores a query string' {
		InModuleScope Neo42.MmsApi {
			Test-MmsDocumentedRoute -Method 'GET' -Path '/api/BitlockerAdRecoveryKey?clientId=42'
		} | Should -BeTrue
	}

	It 'tolerates a trailing slash' {
		InModuleScope Neo42.MmsApi {
			Test-MmsDocumentedRoute -Method 'GET' -Path '/api/Version/'
		} | Should -BeTrue
	}

	It 'reports an invented route as undocumented' {
		InModuleScope Neo42.MmsApi {
			Test-MmsDocumentedRoute -Method 'GET' -Path '/api/NoSuchThing'
		} | Should -BeFalse
	}

	It 'distinguishes the method' {
		# /api/Version exists, but only as a GET. A wrong method has to be
		# reported, otherwise the warning is worthless.
		InModuleScope Neo42.MmsApi {
			Test-MmsDocumentedRoute -Method 'DELETE' -Path '/api/Version'
		} | Should -BeFalse
	}
}

Describe 'Get-MmsSchemaName' -Tag 'Unit' {
	It 'shortens a namespace qualified reference' {
		InModuleScope Neo42.MmsApi {
			Get-MmsSchemaName -Schema ([pscustomobject]@{ '$ref' = '#/definitions/Neo42.MMS.Shared.Model.ClientV2' })
		} | Should -Be 'ClientV2'
	}

	It 'shortens the type arguments of a generic as well' {
		# A ResultModel[...] return type is the signal that a route uses the
		# { Success, Item, Error } envelope and therefore needs -Unwrap.
		InModuleScope Neo42.MmsApi {
			Get-MmsSchemaName -Schema ([pscustomobject]@{ '$ref' = '#/definitions/Neo42.MMS.Shared.Model.ResultModel[Neo42.Bitlocker.Shared.BitlockerReportV2,Neo42.MMS.Shared.ErrorMessageEntry,System.String]' })
		} | Should -Be 'ResultModel[BitlockerReportV2,ErrorMessageEntry,String]'
	}

	It 'marks an array' {
		InModuleScope Neo42.MmsApi {
			Get-MmsSchemaName -Schema ([pscustomobject]@{
					type  = 'array'
					items = [pscustomobject]@{ '$ref' = '#/definitions/Neo42.MMS.Shared.Model.ClientV2' }
				})
		} | Should -Be 'ClientV2[]'
	}

	It 'falls back for an array without a known item type' {
		InModuleScope Neo42.MmsApi {
			Get-MmsSchemaName -Schema ([pscustomobject]@{ type = 'array'; items = $null })
		} | Should -Be 'object[]'
	}

	It 'passes a plain type through' {
		InModuleScope Neo42.MmsApi {
			Get-MmsSchemaName -Schema ([pscustomobject]@{ type = 'string' })
		} | Should -Be 'string'
	}

	It 'returns nothing for nothing' {
		InModuleScope Neo42.MmsApi {
			Get-MmsSchemaName -Schema $null
		} | Should -BeNullOrEmpty
	}
}

Describe 'Find-MmsApiRoute' -Tag 'Unit' {
	It 'finds routes by pattern' {
		@(Find-MmsApiRoute -Pattern 'bitlocker').Count | Should -BeGreaterThan 0
	}

	It 'reports method, path and return type for a hit' {
		$route = @(Find-MmsApiRoute -Pattern '/api/Version') | Select-Object -First 1

		$route.Method | Should -Be 'GET'
		$route.Path | Should -Be '/api/Version'
		$route.ResponseSchema | Should -Not -BeNullOrEmpty
	}

	It 'filters by method' {
		@(Find-MmsApiRoute -Method 'DELETE') | ForEach-Object { $_.Method | Should -Be 'DELETE' }
	}

	It 'returns only changing routes with -WriteOnly' {
		@(Find-MmsApiRoute -WriteOnly) | ForEach-Object { $_.Method | Should -Not -Be 'GET' }
	}

	It 'returns nothing for a pattern that matches no route' {
		@(Find-MmsApiRoute -Pattern 'definitely-not-a-route-xyz').Count | Should -Be 0
	}
}
