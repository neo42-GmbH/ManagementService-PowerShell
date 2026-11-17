<#
	Client deletion - the one write path that cannot be undone.

	Removing a client drops it together with the reports of every plug-in and its
	BitLocker recovery key. The client comes back as soon as its client component
	contacts the server again, but with an empty history. There is no restore.

	So this file refuses to act unless a client is named explicitly:

		Write = @{ DeletableClientNames = @('LAB-CLIENT-01') }

	Three locks, all of which have to be open: IsLab, Write.Enabled, and the name
	on that list. An empty list means this file only verifies that -WhatIf keeps
	its promise, and skips the deletion itself.

	The lookup is by name and the resolved client is checked against the list
	again before anything is sent. A name-to-id mix-up is the mistake that would
	hurt most here, so it is guarded twice.

	An offline client tests strictly more: it stays gone, reports and all. An
	online one re-registers before the delete call returns, so only the reset
	itself is observable. Name an offline client where you can.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:context = Get-MmsTestContext
	$script:target = Connect-MmsTestSession -Context $script:context
	$script:allowed = @($script:context.Write.DeletableClientNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

	$script:skip = $script:context.WriteSkip
	$script:guardSkip = $script:skip
	$script:victim = $null

	if ($null -eq $script:skip) {
		if (0 -eq $script:allowed.Count) {
			$script:skip = 'Write.DeletableClientNames is empty - no client is marked as deletable'
		}
		else {
			$clients = @(Get-MmsClient @script:target)
			$script:victim = @($clients | Where-Object { $_.Name -in $script:allowed })[0]

			if ($null -eq $script:victim) {
				$script:skip = ("none of the clients marked deletable ({0}) is currently registered - " +
					"a previous run may have removed it and it has not re-registered yet") -f ($script:allowed -join ', ')
			}
			else {
				# Decides what may be asserted below - see the file header.
				$script:victimWasOnline = [bool]$script:victim.IsOnline
			}
		}
	}
}

Describe 'client deletion' -Tag 'Write' {

	Context 'the guard holds even without a deletable client' {
		# These run whenever write tests run at all: they need no victim, and
		# they are the part that must never regress.
		BeforeEach {
			if ($null -ne $script:guardSkip) {
				Set-ItResult -Skipped -Because $script:guardSkip
			}
		}

		It 'deletes nothing under -WhatIf, not even a client that exists' {
			$clientsBefore = @(Get-MmsClient @script:target)
			if (0 -eq $clientsBefore.Count) {
				Set-ItResult -Skipped -Because 'no clients registered on this server'
			}

			Remove-MmsClient -ClientId $clientsBefore[0].Id @script:target -WhatIf 6>$null

			@(Get-MmsClient @script:target).Count | Should -Be $clientsBefore.Count
			(Get-MmsClient -Id $clientsBefore[0].Id @script:target) | Should -Not -BeNullOrEmpty
		}

		It 'deletes nothing when a wrapping script runs with -WhatIf' {
			# The exact shape that destroyed a client once: a housekeeping script
			# started with -WhatIf, passing -Confirm:$false on the inner call.
			function Invoke-Housekeeping {
				[CmdletBinding(SupportsShouldProcess)]
				param ([guid] $ClientId, [hashtable] $Target)
				Remove-MmsClient -ClientId $ClientId @Target -Confirm:$false
			}

			$clientsBefore = @(Get-MmsClient @script:target)
			if (0 -eq $clientsBefore.Count) {
				Set-ItResult -Skipped -Because 'no clients registered on this server'
			}

			Invoke-Housekeeping -ClientId $clientsBefore[0].Id -Target $script:target -WhatIf 6>$null

			@(Get-MmsClient @script:target).Count | Should -Be $clientsBefore.Count
		}
	}

	Context 'deleting a client that is marked deletable' {
		BeforeEach {
			if ($null -ne $script:skip) {
				Set-ItResult -Skipped -Because $script:skip
			}
		}

		It 'only ever works on a name from the configured list' {
			# The second lock. If the lookup above ever returned the wrong
			# client, this stops the file before anything is sent.
			$script:victim.Name | Should -BeIn $script:allowed
		}

		It 'removes the client and its plug-in reports' {
			$id = $script:victim.Id

			# By-id: the list route returns the query time as CreationDate.
			$before = Get-MmsClient -Id $id @script:target
			$script:createdBefore = ([datetime]$before.CreationDate).ToUniversalTime()

			Write-Host ("deleting client '{0}' ({1}) - it is marked deletable in the test configuration" -f $script:victim.Name, $id)
			Remove-MmsClient -ClientId $id @script:target -Confirm:$false

			if ($script:victimWasOnline) {
				Set-ItResult -Skipped -Because 'the client is online - its agent re-registers before absence can be observed'
				return
			}

			@(Get-MmsClient @script:target | Where-Object { $_.Id -eq $id }).Count | Should -Be 0
		}

		It 'has dropped the reports of that client as well' {
			$id = $script:victim.Id

			if ($script:victimWasOnline) {
				Set-ItResult -Skipped -Because 'the client is online - it starts reporting again within seconds, so an empty report list is not observable'
				return
			}

			# ServiceInfrastructureV3, not the obsolete client route.
			@(Get-MmsServiceInfrastructureReport @script:target | Where-Object { $_.ClientId -eq $id }).Count |
				Should -Be 0
			@(Get-MmsBitLockerReport @script:target | Where-Object { $_.ClientId -eq $id }).Count |
				Should -Be 0
		}

		It 'stays gone, or comes back as a registration without a history' {
			# Absence is not assertable against a running agent - it re-registers
			# keeping its id. What holds either way: the original record is gone.
			$after = Get-MmsClient -Id $script:victim.Id @script:target -ErrorAction SilentlyContinue

			if ($null -eq $after) {
				Set-ItResult -Skipped -Because 'the client stayed gone - no agent to re-register'
				return
			}

			# No CreationDate yet means the record is still being filled in, which
			# proves the same thing. Version and Sid refill on their own and would
			# only add a race.
			$isFreshRecord = ($null -eq $after.CreationDate) -or
				(([datetime]$after.CreationDate).ToUniversalTime() -gt $script:createdBefore)

			$isFreshRecord | Should -BeTrue -Because 'a re-registration has to be a new record'
		}
	}
}