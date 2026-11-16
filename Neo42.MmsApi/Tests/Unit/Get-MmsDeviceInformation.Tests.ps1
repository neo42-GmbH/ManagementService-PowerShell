<#
	The two parameter sets of Get-MmsDeviceInformation.

	These cases live here and not in Integration\ReadContract.Tests.ps1 because
	they need no server: both are decided during parameter binding, before a
	request is built. In the Integration folder they were also gated on the
	Device Information plug-in being listed in the test configuration, so they
	silently skipped on a server without that plug-in - for a check that never
	touches a server.

	What the server does with the type is a different question and stays in the
	Integration suite, where a real response can contradict it.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	# The wrappers no longer take an address, so a test that must not reach a
	# server builds the session it wants directly.
	$script:unitSession = InModuleScope Neo42.MmsApi { New-MmsApiSessionObject -ServerName 'https://unit.invalid' }
}

Describe 'Get-MmsDeviceInformation parameter sets' -Tag 'Unit' {

	BeforeAll {
		# Nothing here should reach a server. The mock is also the proof: a case
		# that expects a binding failure has to fail at binding, not because the
		# transport was never reachable in the first place.
		Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith { }
	}

	Context 'the list form' {
		It 'sends exactly one request for a type' {
			# The control for the case below: with a -Type the call really is
			# built, so 'the mixed form sends nothing' means something.
			#
			# That -Type is mandatory is deliberately NOT asserted here. Reading
			# it back off the ParameterAttribute only restates the source file,
			# and calling the function without it does not throw in an
			# interactive host - it prompts, stops the run and waits for a human.
			# The claim worth testing is the server's, and it is tested against
			# the server in Integration\ReadContract.Tests.ps1.
			Get-MmsDeviceInformation -Type 'cert' -Session $script:unitSession | Out-Null

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly
		}
	}

	Context 'the two forms do not mix' {
		It 'refuses -Type together with -ClientId and sends nothing' {
			# -Type lists one area for all clients, -ClientId returns every area
			# of one client. There is no route that does both, so the ambiguity
			# has to be rejected rather than silently resolved to one of them.
			# A literal id keeps the case independent of any test configuration.
			#
			# -ErrorId pins the reason: 'Should -Throw' on its own would also be
			# green for a typo in a parameter name, which is the failure this
			# case is least able to notice. The id has to be the whole
			# FullyQualifiedErrorId - Pester compares it as a whole, so the
			# command name belongs in it.
			{ Get-MmsDeviceInformation -Type 'cert' -ClientId '11111111-1111-1111-1111-111111111111' -Session $script:unitSession -ErrorAction Stop } |
				Should -Throw -ErrorId 'AmbiguousParameterSet,Get-MmsDeviceInformation'

			# In the same It on purpose: Should -Invoke counts within the current
			# It, so this assertion in a block of its own would see zero calls
			# whatever happened above and pass for free.
			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 0 -Exactly
		}
	}
}
