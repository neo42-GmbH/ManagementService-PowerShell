<#
	The single choke point every call goes through.

	Everything here is checked by looking at what was handed to the transport,
	never by contacting a server. That covers the parts which are easy to get
	wrong and expensive to notice: url assembly, query encoding, headers, and
	the three different response envelopes the API uses.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	# A test that must not reach a server builds its own session.
	$script:unitSession = InModuleScope Neo42.MmsApi { New-MmsApiSessionObject -ServerName 'https://unit.invalid' }
	$script:portSession = InModuleScope Neo42.MmsApi { New-MmsApiSessionObject -ServerName 'https://unit.invalid:4242' }
}

Describe 'Invoke-MmsApiRequest' -Tag 'Unit' {

	BeforeEach {
		Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith { }
	}

	Context 'url assembly' {
		It 'joins server and path' {
			$null = Invoke-MmsApiRequest -Path '/api/Client' -Session $script:portSession -SkipRouteCheck

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				$Uri -eq 'https://unit.invalid:4242/api/Client'
			}
		}

		It 'tolerates a path without a leading slash' {
			$null = Invoke-MmsApiRequest -Path 'api/Client' -Session $script:unitSession -SkipRouteCheck

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				$Uri -eq 'https://unit.invalid/api/Client'
			}
		}

		It 'url encodes query values' {
			$null = Invoke-MmsApiRequest -Path '/api/client' -Query @{ name = 'domain\host name' } -Session $script:unitSession -SkipRouteCheck

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				$Uri -eq 'https://unit.invalid/api/client?name=domain%5Chost%20name'
			}
		}

		It 'drops a query value that is null instead of sending the word null' {
			$null = Invoke-MmsApiRequest -Path '/api/client' -Query @{ id = $null } -Session $script:unitSession -SkipRouteCheck

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				$Uri -eq 'https://unit.invalid/api/client'
			}
		}
	}

	Context 'headers' {
		It 'sends X-Neo42-Auth Admin by default' {
			$null = Invoke-MmsApiRequest -Path '/api/Client' -Session $script:unitSession -SkipRouteCheck

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				$Headers['X-Neo42-Auth'] -eq 'Admin'
			}
		}

		It 'sends Anonymous where the route wants it' {
			$null = Invoke-MmsApiRequest -Path '/api/TimeService/1' -AuthMode 'Anonymous' -Session $script:unitSession -SkipRouteCheck

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				$Headers['X-Neo42-Auth'] -eq 'Anonymous'
			}
		}

		It 'omits the header completely for AuthMode None' {
			$null = Invoke-MmsApiRequest -Path '/docs/v1/swagger' -AuthMode 'None' -Session $script:unitSession -SkipRouteCheck

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				-not $Headers.ContainsKey('X-Neo42-Auth')
			}
		}

		It 'sets the json content type only when there is a body' {
			$null = Invoke-MmsApiRequest -Path '/api/criteriastorev3' -Method POST -Body @{ Id = 'x' } -Session $script:unitSession -SkipRouteCheck -Confirm:$false

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				$Headers['Content-Type'] -eq 'application/json; charset=utf-8' -and $Body -eq '{"Id":"x"}'
			}
		}

		It 'passes a string body through unchanged' {
			$null = Invoke-MmsApiRequest -Path '/api/criteriastorev3' -Method POST -Body '{"already":"json"}' -Session $script:unitSession -SkipRouteCheck -Confirm:$false

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
				$Body -eq '{"already":"json"}'
			}
		}
	}

	Context 'response shapes' {
		It 'returns a bare response unchanged' {
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith { [pscustomobject]@{ Name = 'CLIENT' } }

			(Invoke-MmsApiRequest -Path '/api/Client' -Session $script:unitSession -SkipRouteCheck).Name | Should -Be 'CLIENT'
		}

		It 'turns the literal string null into no output at all' {
			# Several routes answer "no data" with the four characters null. Left
			# alone that string survives every $null check and only blows up
			# later on a property access.
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith { 'null' }

			@(Invoke-MmsApiRequest -Path '/api/BitlockerAdRecoveryKey' -Session $script:unitSession -SkipRouteCheck).Count | Should -Be 0
		}

		It 'unwraps the Success/Item envelope' {
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith {
				[pscustomobject]@{ Success = $true; Item = [pscustomobject]@{ Id = 'inner' }; Error = $null }
			}

			(Invoke-MmsApiRequest -Path '/api/apc/tenant/all' -Session $script:unitSession -SkipRouteCheck -Unwrap).Id | Should -Be 'inner'
		}

		It 'throws the server reason when Success is false' {
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith {
				[pscustomobject]@{ Success = $false; Item = $null; Error = [pscustomobject]@{ Reason = 'tenant unknown' } }
			}

			{ Invoke-MmsApiRequest -Path '/api/apc/tenant/all' -Session $script:unitSession -SkipRouteCheck -Unwrap } |
				Should -Throw -ExpectedMessage '*tenant unknown*'
		}

		It 'returns nothing countable for an empty Item' {
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith {
				[pscustomobject]@{ Success = $true; Item = $null; Error = $null }
			}

			@(Invoke-MmsApiRequest -Path '/api/apc/tenant/all' -Session $script:unitSession -SkipRouteCheck -Unwrap).Count | Should -Be 0
		}

		It 'unwraps the data/errors/meta envelope' {
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith {
				[pscustomobject]@{ data = @([pscustomobject]@{ Id = 'one' }, [pscustomobject]@{ Id = 'two' }); errors = @(); meta = $null }
			}

			@(Invoke-MmsApiRequest -Path '/api/ServiceInfrastructureV3' -Session $script:unitSession -SkipRouteCheck -Unwrap).Count | Should -Be 2
		}

		It 'throws when the data envelope carries errors' {
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith {
				[pscustomobject]@{ data = $null; errors = @('bad request'); meta = $null }
			}

			{ Invoke-MmsApiRequest -Path '/api/ServiceInfrastructureV3' -Session $script:unitSession -SkipRouteCheck -Unwrap } |
				Should -Throw -ExpectedMessage '*bad request*'
		}

		It 'leaves the envelope alone without -Unwrap' {
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith {
				[pscustomobject]@{ Success = $true; Item = 'inner'; Error = $null }
			}

			(Invoke-MmsApiRequest -Path '/api/apc/tenant/all' -Session $script:unitSession -SkipRouteCheck).Success | Should -BeTrue
		}
	}

	Context 'errors' {
		It 'names method and url, so one log line is enough to find the call' {
			Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith { throw 'boom' }

			{ Invoke-MmsApiRequest -Path '/api/Client' -Session $script:unitSession -SkipRouteCheck } |
				Should -Throw -ExpectedMessage '*GET https://unit.invalid/api/Client*'
		}
	}

	Context 'target resolution' {
		It 'refuses an object that is not a session' {
			{ Invoke-MmsApiRequest -Path '/api/Client' -Session ([pscustomobject]@{ Wrong = $true }) -SkipRouteCheck } |
				Should -Throw -ExpectedMessage '*not an MMS session*'
		}

		It 'uses the connection from Connect-MmsApi when no session is passed' {
			InModuleScope Neo42.MmsApi {
				$script:MmsSession = New-MmsApiSessionObject -ServerName 'https://ambient.invalid' -Source 'Session'
			}
			try {
				$null = Invoke-MmsApiRequest -Path '/api/Client' -SkipRouteCheck

				Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly -ParameterFilter {
					$Uri -eq 'https://ambient.invalid/api/Client'
				}
			}
			finally {
				InModuleScope Neo42.MmsApi { $script:MmsSession = $null }
			}
		}
	}
}
