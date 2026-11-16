<#
	What happens when something is wrong, against a real server.

	Error paths are where a client library is usually thin, and they are what
	someone reads at three in the morning. Every message checked here has to name
	enough to act on: the status code, the route, or the next command to run.

	The second half is the -WhatIf proof with a real session. It complements the
	offline test in Unit\Test-MmsShouldProcess.Tests.ps1, which asserts against a
	mocked transport; here a real connection is in place, and the request would
	really go out.

	Every destructive case deliberately uses a freshly generated guid, not a real
	id. If a -WhatIf ever stopped working, the request would hit a non existent
	object and this test would fail with a 404 - loudly, and without destroying
	anything. That is the only responsible way to test a delete path against a
	server.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:context = Get-MmsTestContext
	$script:target = Connect-MmsTestSession -Context $script:context

	# Write-Verbose inside the module obeys the module's own $VerbosePreference
	# and not the -Verbose of a calling script - the same scope gap that makes
	# Test-MmsShouldProcess necessary in the first place. Without this the
	# request line the -WhatIf cases below use as evidence never appears at all,
	# and they are green whether or not a request went out.
	if ($null -eq $script:context.IntegrationSkip) {
		InModuleScope Neo42.MmsApi { $script:VerbosePreference = 'Continue' }
	}
}

AfterAll {
	if ($null -eq $script:context.IntegrationSkip) {
		InModuleScope Neo42.MmsApi { $script:VerbosePreference = 'SilentlyContinue' }
	}
}

Describe 'error paths' -Tag 'Integration' {

	BeforeEach {
		if ($null -ne $script:context.IntegrationSkip) {
			Set-ItResult -Skipped -Because $script:context.IntegrationSkip
		}
	}

	Context 'a request that the server rejects' {
		It 'reports the status code and the route' {
			$message = try {
				Get-MmsBitLockerPolicy -Id ([guid]::NewGuid()) @script:target -ErrorAction Stop
				$null
			}
			catch {
				$_.Exception.Message
			}

			if ($null -eq $message) {
				Set-ItResult -Skipped -Because 'this server answers an unknown policy id without an error'
			}

			$message | Should -Match 'HTTP \d{3}'
			$message | Should -Match '/api/'
		}

		It 'reports an unknown route as 404, not as a parse error' {
			$message = try {
				Invoke-MmsApiRequest -Path '/api/DefinitelyNotARoute' @script:target -SkipRouteCheck -ErrorAction Stop
				$null
			}
			catch {
				$_.Exception.Message
			}

			$message | Should -Not -BeNullOrEmpty
			$message | Should -Match 'HTTP 404'
		}
	}

	Context 'a request with no data behind it' {
		It 'returns nothing countable for an unknown pipeline run' {
			@(Get-MmsApcPipelineRun -RunId ([guid]::NewGuid()) @script:target -ErrorAction SilentlyContinue).Count |
				Should -Be 0
		}
	}

	Context 'a target that does not exist locally' {
		It 'names the known profiles for an unknown profile' {
			{ Get-MmsConnectionProfile -Name 'no-such-profile-in-this-test' -ErrorAction Stop } |
				Should -Throw -ExpectedMessage '*No MMS connection profile*'
		}
	}

	Context 'the undocumented route warning' {
		It 'warns for a route that is not in the documented surface' {
			# The warning comes before the request, the 404 after it, and the
			# module throws on a failed call - so the call has to be caught to
			# get at the warning. -ErrorAction does not help against throw.
			#
			# The module warns once per route and session. Without emptying that
			# cache first the outcome depends on what ran before, which is how
			# the case below came to be green for the wrong reason.
			InModuleScope Neo42.MmsApi { $script:MmsUndocumentedRouteWarnings = @{} }

			$warnings = @()
			try {
				$null = Invoke-MmsApiRequest -Path '/api/DefinitelyNotARoute' @script:target -WarningVariable warnings -WarningAction SilentlyContinue
			}
			catch {
				# expected: the route does not exist
			}

			@($warnings).Count | Should -BeGreaterThan 0
			($warnings -join ' ') | Should -Match 'documented API surface'
		}

		It 'does not warn for a documented route' {
			# Same cache, and here it decides everything: Connect-MmsApi already
			# asked for the version, so with a spent cache this case stayed green
			# even while the module warned about every route it was given.
			InModuleScope Neo42.MmsApi { $script:MmsUndocumentedRouteWarnings = @{} }

			$warnings = @()
			$null = Get-MmsServerVersion @script:target -WarningVariable warnings -WarningAction SilentlyContinue

			@($warnings) | Should -BeNullOrEmpty
		}
	}

	Context '-WhatIf with a real session sends nothing' {
		It '<Wrapper> builds no request' -ForEach @(
			@{ Wrapper = 'Remove-MmsClient'; Call = { Remove-MmsClient -ClientId ([guid]::NewGuid()) @script:target -Confirm:$false } }
			@{ Wrapper = 'Remove-MmsNotification'; Call = { Remove-MmsNotification -NotificationGuid ([guid]::NewGuid()) @script:target -Confirm:$false } }
			@{ Wrapper = 'Send-MmsClientNotification'; Call = { Send-MmsClientNotification -TargetGuid ([guid]::NewGuid()) -Message 'integration test, never sent' @script:target -Confirm:$false } }
		) {
			# Invoke-MmsApiRequest writes its verbose line only after the
			# ShouldProcess guard has passed, so the absence of that line is the
			# evidence that nothing went out. That evidence only exists because
			# BeforeAll raised $VerbosePreference inside the module: -Verbose on
			# the calling script below does not reach a module function, so this
			# case used to be unable to fail.
			function Invoke-CallingScript {
				[CmdletBinding(SupportsShouldProcess)]
				param ([scriptblock] $Body)
				& $Body
			}

			$verbose = @()
			Invoke-CallingScript -Body $Call -WhatIf 4>&1 6>$null |
				ForEach-Object { $verbose += [string]$_ }

			($verbose -join ' ') | Should -Not -Match 'https?://' -Because 'a verbose request line means the call was actually made'
		}

		It 'the same call without -WhatIf really would reach the server' {
			# The control. Without it the assertions above would also pass for a
			# call that was broken for an entirely different reason.
			#
			# The status code cannot carry that proof: deleting an id that does
			# not exist is accepted as a no-op on this server, so there is no
			# message to inspect, and a module that suppressed every write would
			# have passed this case in silence. The request line is the evidence
			# that something actually left the module - the same line whose
			# absence the cases above rely on.
			$verbose = @()
			$message = $null
			try {
				Remove-MmsClient -ClientId ([guid]::NewGuid()) @script:target -Confirm:$false -ErrorAction Stop 4>&1 |
					ForEach-Object { $verbose += [string]$_ }
			}
			catch {
				$message = $_.Exception.Message
			}

			($verbose -join ' ') | Should -Match 'https?://' -Because 'without a request line nothing was sent, and the -WhatIf cases above would be green for the wrong reason'

			# And if the server does refuse it, it has to say so in a way that
			# names the status.
			if ($null -ne $message) {
				$message | Should -Match 'HTTP \d{3}'
			}
		}
	}
}
