<#
	The notification lifecycle: send, read back, delete.

	Rules this file follows, and every write test should:

	- It only touches what it created itself. The notification is created here
	  and carries its own id; nothing that existed before is read for deletion.
	- Cleanup runs in AfterAll, not at the end of the last It. A test that fails
	  in the middle of the chain must not leave the server dirty.
	- The chain is one Context and depends on order. That is the exception write
	  tests are allowed - a lifecycle cannot be asserted in independent cases -
	  and it is why the created id is kept in a script variable.
	- Nothing here waits for a human. The client may be offline; the delivery
	  fields are then simply reported as not yet set instead of failing.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:context = Get-MmsTestContext
	$script:target = Connect-MmsTestSession -Context $script:context

	# Everything this file created, for AfterAll. Filled as things are created,
	# so a failure halfway through still cleans up.
	$script:createdNotifications = @()
	$script:skip = $script:context.WriteSkip
	$script:client = $null

	if ($null -eq $script:skip) {
		$configuredName = $script:context.Write.NotificationClientName
		if ([string]::IsNullOrWhiteSpace($configuredName)) {
			$script:skip = 'Write.NotificationClientName is not set in the test configuration'
		}
		else {
			$script:client = @(Get-MmsClient @script:target | Where-Object { $_.Name -eq $configuredName })[0]
			if ($null -eq $script:client) {
				$script:skip = "Write.NotificationClientName names '$configuredName', which does not exist on this server"
			}
		}
	}
}

AfterAll {
	foreach ($id in $script:createdNotifications) {
		try {
			Remove-MmsNotification -NotificationGuid $id @script:target -Confirm:$false -ErrorAction Stop
			Write-Host ("cleanup: removed notification {0}" -f $id)
		}
		catch {
			# Already gone is the normal case - the last test deletes it. Only a
			# different failure is worth reporting.
			if ($_.Exception.Message -notmatch 'HTTP 404') {
				Write-Warning ("cleanup of notification {0} failed: {1}" -f $id, $_.Exception.Message)
			}
		}
	}
}

Describe 'notification lifecycle' -Tag 'Write' {

	BeforeEach {
		if ($null -ne $script:skip) {
			Set-ItResult -Skipped -Because $script:skip
		}
	}

	Context 'send, read, delete' {

		It 'sends nothing under -WhatIf' {
			# The preview first, exactly the way a human is asked to do it before
			# a write path is let loose. If this were broken the whole file would
			# be untrustworthy.
			$before = @(Get-MmsNotification @script:target).Count

			$id = Send-MmsClientNotification -TargetGuid $script:client.Id `
				-Message 'Neo42.MmsApi write test - must never be sent' `
				@script:target -PassThru -WhatIf 6>$null

			$id | Should -BeNullOrEmpty
			@(Get-MmsNotification @script:target).Count | Should -Be $before
		}

		It 'sends a notification and returns its id' {
			$script:notificationId = Send-MmsClientNotification -TargetGuid $script:client.Id `
				-Message 'Neo42.MmsApi write test' `
				-Message2 'Created by the test suite, deleted again immediately.' `
				-MessageHeader 'Automated test' `
				-Theme 'Light' `
				-NotificationGroup 'Neo42.MmsApi tests' `
				@script:target -PassThru -Confirm:$false

			$script:notificationId | Should -Not -BeNullOrEmpty
			$script:notificationId | Should -BeOfType [guid]

			# Register for cleanup before anything else can fail.
			$script:createdNotifications += $script:notificationId
		}

		It 'can be read back by id' {
			$notification = Get-MmsNotification -NotificationGuid $script:notificationId @script:target

			$notification | Should -Not -BeNullOrEmpty
			$notification.Notification.Id | Should -Be $script:notificationId
		}

		It 'carries the target client and the text that was sent' {
			$notification = Get-MmsNotification -NotificationGuid $script:notificationId @script:target

			@($notification.Targets.ClientId) | Should -Contain $script:client.Id
			@($notification.Notification.Message.Lines.Value) | Should -Contain 'Neo42.MmsApi write test'
			@($notification.Notification.Message.Headers.Value) | Should -Contain 'Automated test'
		}

		It 'appears in the list for that client' {
			$forClient = @(Get-MmsNotification -ClientId $script:client.Id @script:target)

			@($forClient.Notification.Id) | Should -Contain $script:notificationId
		}

		It 'reports a delivery state per target' {
			$notification = Get-MmsNotification -NotificationGuid $script:notificationId @script:target
			$targetEntry = @($notification.Targets | Where-Object { $_.ClientId -eq $script:client.Id })[0]

			# IsSent depends on whether the client has picked it up, so only the
			# field is asserted, not its value. ReceivedTime stays null until the
			# user confirms - that is not a failure of this test.
			@($targetEntry.PSObject.Properties.Name) | Should -Contain 'IsSent'
			@($targetEntry.PSObject.Properties.Name) | Should -Contain 'ReceivedTime'
		}

		It 'is not deleted under -WhatIf' {
			Remove-MmsNotification -NotificationGuid $script:notificationId @script:target -WhatIf 6>$null

			Get-MmsNotification -NotificationGuid $script:notificationId @script:target | Should -Not -BeNullOrEmpty
		}

		It 'is gone after Remove-MmsNotification' {
			Remove-MmsNotification -NotificationGuid $script:notificationId @script:target -Confirm:$false

			$remaining = @(Get-MmsNotification @script:target | Where-Object { $_.Notification.Id -eq $script:notificationId })
			$remaining.Count | Should -Be 0

			# Nothing left for AfterAll to do.
			$script:createdNotifications = @($script:createdNotifications | Where-Object { $_ -ne $script:notificationId })
		}
	}
}
