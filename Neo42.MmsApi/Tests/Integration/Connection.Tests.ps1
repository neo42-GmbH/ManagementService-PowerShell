<#
	Reachability, authentication and the age of the API snapshot.

	Read only. Run this first when something is wrong: it separates 'server not
	reachable' from 'not allowed' from 'API documentation switched off', which is
	otherwise one indistinguishable connection error.

	The snapshot comparison at the end is the trigger for the whole breaking
	change routine - when it fails, the module is describing an API version the
	server no longer runs.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:context = Get-MmsTestContext

	# This file is the one that exercises Connect-MmsApi itself, so it needs
	# both: the arguments to connect with, and a session to call wrappers with.
	$script:connectArgs = $script:context.Target
	$script:target = Connect-MmsTestSession -Context $script:context
}

Describe 'connection to the configured MMS' -Tag 'Integration' {

	BeforeEach {
		if ($null -ne $script:context.IntegrationSkip) {
			Set-ItResult -Skipped -Because $script:context.IntegrationSkip
		}
	}

	Context 'Test-MmsApiConnection' {
		BeforeAll {
			if ($null -eq $script:context.IntegrationSkip) {
				$script:probe = Test-MmsApiConnection @script:target
			}
		}

		It 'reaches the API listener' {
			$script:probe.Reachable | Should -BeTrue -Because 'name resolution, port, certificate and service all have to be in order'
		}

		It 'authenticates the account running the tests' {
			$script:probe.Authenticated | Should -BeTrue -Because ($script:probe.Errors -join '; ')
		}

		It 'reports a server version' {
			$script:probe.ServerVersion | Should -Not -BeNullOrEmpty
		}

		It 'has the API documentation switched on' {
			# Without it Find-MmsApiRoute and the undocumented route warning are
			# blind, and Tools\Update-MmsApiCatalog.ps1 cannot refresh anything.
			$script:probe.ApiDocumentationActive | Should -BeTrue -Because "the server setting 'EnableApiDocumentation' has to be active"
		}

		It 'collects no errors at all' {
			@($script:probe.Errors) | Should -BeNullOrEmpty
		}
	}

	Context 'the anonymous probe' {
		It 'returns a server time without an authenticated user' {
			Get-MmsServerTime @script:target | Should -Not -BeNullOrEmpty
		}
	}

	Context 'session lifecycle' {
		It 'connects, reports the session and disconnects again' {
			$session = Connect-MmsApi @script:connectArgs -PassThru

			$session.ServerName | Should -Not -BeNullOrEmpty
			$session.AuthMode | Should -BeIn @('Windows', 'Credential')
			$session.ServerVersion | Should -Not -BeNullOrEmpty
			$session.PSObject.TypeNames | Should -Contain 'Neo42.MmsApi.Session'

			(Get-MmsApiSession).ServerName | Should -Be $session.ServerName

			Disconnect-MmsApi -Confirm:$false
			Get-MmsApiSession -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
		}

		It 'carries no secret in the session object of a Windows connection' {
			$session = Connect-MmsApi @script:connectArgs -PassThru

			$session.Credential | Should -BeNullOrEmpty

			Disconnect-MmsApi -Confirm:$false
		}

		It 'reports an unreachable address as a connection failure, not as a hang' {
			# .invalid never resolves (RFC 2606), so this is a real negative test
			# and not a wait for a timeout.
			{ Connect-MmsApi -ServerName 'https://does-not-exist.invalid:4242' -ErrorAction Stop } |
				Should -Throw
		}
	}

	Context 'the API snapshot matches the server' {
		It 'was taken from the version this server runs' {
			$snapshotMeta = Join-Path -Path (Split-Path -Path (Get-MmsTestModuleManifest) -Parent) -ChildPath 'docs\swagger-v1.meta.json'
			$expected = (Get-Content -LiteralPath $snapshotMeta -Raw -Encoding UTF8 | ConvertFrom-Json).ServerVersion
			$actual = (Get-MmsServerVersion @script:target).ToString()

			$actual | Should -Be $expected -Because 'refresh it with Tools\Update-MmsApiCatalog.ps1 and then run the Unit tests again - they list the routes that no longer exist'
		}
	}
}
