<#
	Address normalisation. Pure function, no server, no mocks needed.

	It is worth its own file because every single call of the module goes through
	it, and because the API listener has its own port - a wrong address here
	fails much later with a confusing error.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest
}

Describe 'Format-MmsServerName' -Tag 'Unit' {

	Context 'accepted input' {
		It 'turns <Given> into <Expected>' -ForEach @(
			@{ Given = 'server.domain'; Expected = 'https://server.domain' }
			@{ Given = 'server.domain:4242'; Expected = 'https://server.domain:4242' }
			@{ Given = 'https://server.domain:4242'; Expected = 'https://server.domain:4242' }
			@{ Given = 'http://server.domain:4242'; Expected = 'http://server.domain:4242' }
			@{ Given = 'https://server.domain:4242/'; Expected = 'https://server.domain:4242' }
			@{ Given = '  https://server.domain:4242  '; Expected = 'https://server.domain:4242' }
			@{ Given = 'HTTPS://server.domain:4242'; Expected = 'HTTPS://server.domain:4242' }
		) {
			InModuleScope Neo42.MmsApi -Parameters @{ Value = $Given } {
				param ($Value)
				Format-MmsServerName -ServerName $Value
			} | Should -Be $Expected
		}

		It 'never returns a trailing slash, so paths can be concatenated' {
			InModuleScope Neo42.MmsApi {
				Format-MmsServerName -ServerName 'https://server.domain:4242/'
			} | Should -Not -Match '/$'
		}

		It 'accepts the BaseUri alias that earlier builds used' {
			InModuleScope Neo42.MmsApi {
				Format-MmsServerName -BaseUri 'server.domain:4242'
			} | Should -Be 'https://server.domain:4242'
		}
	}

	Context 'rejected input' {
		It 'rejects <Given> and says why' -ForEach @(
			@{ Given = 'ftp://server.domain'; Match = '*unsupported scheme*' }
			@{ Given = 'file://server/share'; Match = '*unsupported scheme*' }
		) {
			{
				InModuleScope Neo42.MmsApi -Parameters @{ Value = $Given } {
					param ($Value)
					Format-MmsServerName -ServerName $Value
				}
			} | Should -Throw -ExpectedMessage $Match
		}

		It 'rejects an empty address' {
			{
				InModuleScope Neo42.MmsApi {
					Format-MmsServerName -ServerName ''
				}
			} | Should -Throw
		}
	}
}
