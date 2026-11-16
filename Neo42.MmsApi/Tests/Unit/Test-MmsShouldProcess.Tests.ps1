<#
	The -WhatIf / -Confirm contract across the module boundary.

	This is the reference test of this suite. It exists because the bug it covers
	has already destroyed a real client record: a housekeeping script started
	with -WhatIf deleted a client for real, because a function exported from a
	module runs in module scope and does not inherit $WhatIfPreference from the
	script that called it.

	Three things make this test worth copying:

	1. It runs offline. Invoke-RestMethod is mocked inside the module, so the
	   assertion is 'was a request built and handed to the transport', not 'did a
	   server change'. No server, no lab, no cleanup.
	2. Every 'nothing happened' assertion has a control that proves the same call
	   DOES happen when nothing suppresses it. Without the control a test passes
	   just as happily when the call fails on a typo in a parameter name.
	3. It is data driven over every write function, so a new write function is
	   covered the moment it is added to the table below - and a write function
	   that forgets Test-MmsShouldProcess fails here instead of in production.
#>

BeforeDiscovery {
	# The -ForEach data has to exist at discovery time, so it cannot come from
	# BeforeAll. Each scriptblock is self contained (literal ids, no outer
	# variables, no target) because it is built here and invoked later in
	# another scope.
	#
	# Ids are syntactically valid but deliberately meaningless: the transport is
	# mocked, so nothing is ever resolved on a server.
	$script:writeCalls = @(
		@{ Function = 'Remove-MmsClient'
			Call = { Remove-MmsClient -ClientId '11111111-1111-1111-1111-111111111111' -Confirm:$false } }
		@{ Function = 'Remove-MmsNotification'
			Call = { Remove-MmsNotification -NotificationGuid '22222222-2222-2222-2222-222222222222' -Confirm:$false } }
		@{ Function = 'Remove-MmsPendingNotification'
			Call = { Remove-MmsPendingNotification -Confirm:$false } }
		@{ Function = 'Send-MmsClientNotification'
			Call = { Send-MmsClientNotification -TargetGuid '33333333-3333-3333-3333-333333333333' -Message 'unit test' -Confirm:$false } }
		@{ Function = 'Send-MmsClientMessage'
			Call = { Send-MmsClientMessage -ClientId '44444444-4444-4444-4444-444444444444' -Header 'unit test' -Confirm:$false } }
		@{ Function = 'Set-MmsFilter'
			Call = { Set-MmsFilter -Filter ([pscustomobject]@{ Id = 'unit-filter'; Criteria = '{}' }) -Confirm:$false } }
		@{ Function = 'New-MmsApcEmpCleanupJob'
			Call = { New-MmsApcEmpCleanupJob -TenantId '55555555-5555-5555-5555-555555555555' -CleanupAction 'AllPackages' -Confirm:$false } }
		@{ Function = 'Test-MmsApcEmpCleanupDuplicates'
			Call = { Test-MmsApcEmpCleanupDuplicates -TenantId '55555555-5555-5555-5555-555555555555' -EmpirumCleanupItems @([pscustomobject]@{ Id = 'p1' }) -JobId '66666666-6666-6666-6666-666666666666' -Confirm:$false } }
		@{ Function = 'Start-MmsApcEmpCleanupJob'
			Call = { Start-MmsApcEmpCleanupJob -JobId '66666666-6666-6666-6666-666666666666' -EmpirumCleanupItems @([pscustomobject]@{ Id = 'p1' }) -Confirm:$false } }
		@{ Function = 'Remove-MmsApcEmpCleanupJob'
			Call = { Remove-MmsApcEmpCleanupJob -JobId '66666666-6666-6666-6666-666666666666' -Confirm:$false } }
		@{ Function = 'Start-MmsApcPipeline'
			Call = { Start-MmsApcPipeline -PipelineId '0123456789abcdef01234567' -Confirm:$false } }
		@{ Function = 'Stop-MmsApcPipelineRun'
			Call = { Stop-MmsApcPipelineRun -RunId '77777777-7777-7777-7777-777777777777' -Confirm:$false } }
		@{ Function = 'Remove-MmsApcPipelineRun'
			Call = { Remove-MmsApcPipelineRun -RunId '77777777-7777-7777-7777-777777777777' -Confirm:$false } }
		@{ Function = 'Remove-MmsApcPipelineVariable'
			Call = { Remove-MmsApcPipelineVariable -Id 'unit-variable' -Confirm:$false } }
		@{ Function = 'Start-MmsApcPackageSync'
			Call = { Start-MmsApcPackageSync -Confirm:$false } }
		@{ Function = 'Find-MmsApcPipeline'
			Call = { Find-MmsApcPipeline -Tag 'unit' -Confirm:$false } }
		@{ Function = 'Get-MmsApcNetworkDriveFile'
			Call = { Get-MmsApcNetworkDriveFile -NetworkDriveId '88888888-8888-8888-8888-888888888888' -Confirm:$false } }
	)
}

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	# The target comes from the session, as after Connect-MmsApi. unit.invalid
	# never resolves (RFC 2606), so a leaked request dies in DNS.
	InModuleScope Neo42.MmsApi {
		$script:MmsSession = New-MmsApiSessionObject -ServerName 'https://unit.invalid' -Source 'Session'
	}

	# Stands in for a housekeeping script: SupportsShouldProcess, and it passes
	# -Confirm:$false on the inner call the way an unattended script does. That
	# combination is exactly what used to delete data under -WhatIf.
	function Invoke-CallingScript {
		[CmdletBinding(SupportsShouldProcess)]
		param (
			[Parameter(Mandatory = $true)]
			[scriptblock]
			$Body
		)
		& $Body
	}
}

AfterAll {
	InModuleScope Neo42.MmsApi { $script:MmsSession = $null }
}

Describe 'Test-MmsShouldProcess' -Tag 'Unit' {

	BeforeEach {
		# Mocked in the module scope, so it also covers the private helpers and
		# the nested call from a wrapper into Invoke-MmsApiRequest.
		Mock -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -MockWith { }
		Mock -CommandName Invoke-WebRequest -ModuleName Neo42.MmsApi -MockWith { [pscustomobject]@{ Content = '' } }
	}

	Context 'control - the request really is built' {
		# Without this context the suppression tests below would also pass for a
		# call that never worked in the first place.
		It '<Function> hands exactly one request to the transport' -ForEach $writeCalls {
			& $Call 3>$null 6>$null

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly `
				-Because 'the control proves the parameters are right, so a suppressed call means something'
		}
	}

	Context 'a wrapping script started with -WhatIf' {
		It '<Function> sends nothing' -ForEach $writeCalls {
			Invoke-CallingScript -Body $Call -WhatIf 3>$null 6>$null

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 0 -Exactly `
				-Because 'a module function does not inherit $WhatIfPreference, so it has to read it from the caller session state'
		}

		It '<Function> still reports what it would have done' -ForEach $writeCalls {
			# The preview line is the whole point of -WhatIf, so silence would be
			# a regression even though nothing was sent. Write-Host goes to the
			# information stream, hence 6>&1.
			#
			# -Width 500 is not cosmetic: Out-String wraps at the width of the
			# host, so the preview arrives with a line break in the middle
			# whenever the console is narrower than the message. An assertion
			# that only matches at the start of a line survives that; one that
			# matches further in fails on a narrow window and passes on a wide
			# one. See the target assertion below, which is where it bit.
			$preview = Invoke-CallingScript -Body $Call -WhatIf 6>&1 3>$null | Out-String -Width 500

			$preview | Should -Match 'What if: Performing the operation'
		}
	}

	Context '-WhatIf on the module function itself' {
		It 'Remove-MmsClient sends nothing' {
			Remove-MmsClient -ClientId '11111111-1111-1111-1111-111111111111' -WhatIf 6>$null

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 0 -Exactly
		}

		It 'names the target in the preview' {
			# The target sits at the end of a 139 character line, so this is the
			# assertion that fails without -Width: at a console width of 120 the
			# guid is split across two lines and no longer matches.
			$preview = Remove-MmsClient -ClientId '11111111-1111-1111-1111-111111111111' -WhatIf 6>&1 | Out-String -Width 500

			$preview | Should -Match 'client 11111111-1111-1111-1111-111111111111'
		}
	}

	Context 'an explicit switch on the inner call wins over the caller' {
		It 'takes -WhatIf:$false even inside a -WhatIf script' {
			# Deliberate escape hatch: a script may need one call to happen for
			# real while previewing the rest.
			$body = { Remove-MmsClient -ClientId '11111111-1111-1111-1111-111111111111' -WhatIf:$false -Confirm:$false }

			Invoke-CallingScript -Body $body -WhatIf 3>$null 6>$null

			Should -Invoke -CommandName Invoke-RestMethod -ModuleName Neo42.MmsApi -Times 1 -Exactly
		}
	}

	Context 'a -Confirm the user asked for is not swallowed by an inner -Confirm:$false' {
		It 'prompts instead of acting' {
			# Run in a child process, and not here, because the behaviour under
			# test IS a prompt. In a console this case used to stop the whole
			# suite at '[Y] Yes [N] No', and the default is Yes: whoever pressed
			# Enter to get the run moving again accepted the deletion and the
			# test reported a pass for a request that really went out. It only
			# ever looked green because ShouldContinue throws in a host that
			# cannot prompt - so the assertion held in CI and broke in front of
			# a human, which is the wrong way round for this of all paths.
			#
			# TestHelpers\ConfirmProbe.ps1 makes that host explicit with
			# -NonInteractive instead of inheriting whatever started the suite.
			$probe = Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\ConfirmProbe.ps1'

			$output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
				-File $probe -Manifest (Get-MmsTestModuleManifest)

			$result = @{}
			foreach ($line in $output) {
				if ($line -match '^(THREW|MESSAGE)=(.*)$') { $result[$Matches[1]] = $Matches[2] }
			}

			# Both halves of the claim, and both have teeth: dropping the outer
			# -Confirm in the probe swaps one message for the other, which is how
			# the pair was checked. 'it threw' on its own would be green either
			# way - the transport failure throws too.
			$result['THREW'] | Should -Be 'yes'
			$result['MESSAGE'] | Should -BeLike '*ShouldContinue*' -Because 'the caller has to be asked, and asking is what fails in a host that cannot prompt'
			$result['MESSAGE'] | Should -Not -BeLike '*MMS API call failed*' -Because 'reaching the transport at all means the inner -Confirm:$false swallowed the users -Confirm'
		}
	}
}
