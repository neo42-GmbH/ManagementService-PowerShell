<#
	Translation of a session into request parameters.

	One branch per authentication mode. Getting this wrong is not a crash but a
	401 against a customer server, so both modes are checked offline.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest
}

Describe 'Add-MmsAuthentication' -Tag 'Unit' {

	Context 'Windows integrated (the default)' {
		It 'uses the logged on user' {
			$result = InModuleScope Neo42.MmsApi {
				$parameters = @{}
				$headers = @{}
				$session = New-MmsApiSessionObject -ServerName 'https://unit.invalid'
				Add-MmsAuthentication -Parameters $parameters -Headers $headers -Session $session
				[pscustomobject]@{ Parameters = $parameters; Headers = $headers }
			}

			$result.Parameters['UseDefaultCredentials'] | Should -BeTrue
			$result.Parameters.ContainsKey('Credential') | Should -BeFalse
			$result.Headers.ContainsKey('Authorization') | Should -BeFalse
		}
	}

	Context 'credential' {
		It 'passes the credential and does not fall back to the current user' {
			$result = InModuleScope Neo42.MmsApi {
				$parameters = @{}
				$headers = @{}
				$credential = New-Object System.Management.Automation.PSCredential(
					'EXAMPLE\svc-mms',
					(ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force))
				$session = New-MmsApiSessionObject -ServerName 'https://unit.invalid' -AuthMode 'Credential' -Credential $credential
				Add-MmsAuthentication -Parameters $parameters -Headers $headers -Session $session
				[pscustomobject]@{ Parameters = $parameters; Headers = $headers }
			}

			$result.Parameters['Credential'].UserName | Should -Be 'EXAMPLE\svc-mms'
			$result.Parameters.ContainsKey('UseDefaultCredentials') | Should -BeFalse
		}

		It 'says what to do when the session has no credential' {
			{
				InModuleScope Neo42.MmsApi {
					$session = New-MmsApiSessionObject -ServerName 'https://unit.invalid' -AuthMode 'Credential'
					Add-MmsAuthentication -Parameters @{} -Headers @{} -Session $session
				}
			} | Should -Throw -ExpectedMessage '*Connect-MmsApi -Credential*'
		}
	}

	Context 'there is no token mode' {
		# A third mode reaching the factory would fall into the Windows branch
		# and authenticate as the wrong identity rather than fail.
		It 'refuses an AuthMode the module does not implement' {
			{
				InModuleScope Neo42.MmsApi {
					New-MmsApiSessionObject -ServerName 'https://unit.invalid' -AuthMode 'Token'
				}
			} | Should -Throw
		}
	}
}
