<#
	The fields the module and the example scripts actually read.

	This is the contract an MMS update can break without any route disappearing:
	a property renamed, moved into a sub object, or suddenly null. Every field
	checked here is one that a wrapper or an example script dereferences, so a
	failure means real code stops working - not that some model changed.

	Read only, and never assert on a value that must not appear in a log: for the
	BitLocker recovery key only presence and type are checked, never the key
	itself. A failed assertion prints its input, and test output ends up in
	consoles and result files.

	Everything that supports it is read with -Limit 1. The full Empirum report on
	a small lab server is already 8000 rows and took ten seconds; one row proves
	the shape just as well, and a suite nobody waits for gets run by nobody.

	A plug-in that is not licensed or simply has no data yet reports as skipped.
	A skip is an open question, not a pass - Invoke-MmsTests.ps1 lists them.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:context = Get-MmsTestContext
	$script:target = Connect-MmsTestSession -Context $script:context
	$script:plugins = @($script:context.Integration.Plugins)

	function Test-PluginConfigured {
		param ([string] $Name)
		return ($script:plugins -contains $Name)
	}

	function Assert-HasProperty {
		<#
			Presence, not value: several report fields are legitimately null on a
			client that has not reported yet, while a renamed or removed property
			is the breaking change.

			A dotted name walks into a sub object, because some reports nest the
			payload - the Empirum report keeps the client id in Report.ClientId,
			and that nesting is as much part of the contract as the name.
		#>
		param ([psobject] $Object, [string[]] $Property)

		foreach ($path in $Property) {
			$current = $Object
			$walked = @()

			foreach ($segment in ($path -split '\.')) {
				@($current.PSObject.Properties.Name) |
					Should -Contain $segment -Because ("expected {0} on the response{1}" -f $path, $(if ($walked.Count) { " (found $($walked -join '.'))" } else { '' }))
				$current = $current.$segment
				$walked += $segment
			}
		}
	}

	if ($null -eq $script:context.IntegrationSkip) {
		$script:clients = @(Get-MmsClient @script:target)

		$configuredName = $script:context.Integration.ClientName
		$script:client = if (-not [string]::IsNullOrWhiteSpace($configuredName)) {
			@($script:clients | Where-Object { $_.Name -eq $configuredName })[0]
		}
		else {
			$script:clients[0]
		}
	}
}

Describe 'read contract' -Tag 'Integration' {

	BeforeEach {
		if ($null -ne $script:context.IntegrationSkip) {
			Set-ItResult -Skipped -Because $script:context.IntegrationSkip
		}
	}

	Context 'MMS information' {
		It 'Get-MmsServerVersion returns a version object' {
			$version = Get-MmsServerVersion @script:target

			$version | Should -BeOfType [version]
			$version.Major | Should -BeGreaterThan 0
		}
	}

	Context 'clients - the join key of every plug-in' {
		It 'Get-MmsClient returns at least one client' {
			@($script:clients).Count | Should -BeGreaterThan 0 -Because 'without a client nothing else in this file can be checked'
		}

		It 'the configured client was found' {
			$script:client | Should -Not -BeNullOrEmpty -Because "Integration.ClientName in the test configuration names a client that has to exist on this server"
		}

		It 'a client carries the fields the example scripts read' {
			Assert-HasProperty -Object $script:client -Property 'Id', 'Name', 'Domain', 'NetBiosName', 'IsOnline', 'LastAccess'
		}

		It 'NetBiosName is DOMAIN\NAME, and Name is the short name' {
			# The example scripts rely on this difference: Get-MmsClient -Name
			# takes the short name, so a swap here breaks every by-name lookup.
			$script:client.NetBiosName | Should -Match '\\'
			$script:client.Name | Should -Not -Match '\\'
		}

		It 'Get-MmsClient -Id returns the same client' {
			(Get-MmsClient -Id $script:client.Id @script:target).Name | Should -Be $script:client.Name
		}

		It 'Get-MmsClient -Domain -Name returns the same client' {
			(Get-MmsClient -Domain $script:client.Domain -Name $script:client.Name @script:target).Id |
				Should -Be $script:client.Id
		}
	}

	Context 'report plug-ins' {
		# One case per plug-in, with the path where the client id lives. The
		# paths differ on purpose and are the interesting part: the Empirum
		# report wraps its payload, the others do not.
		It '<Wrapper> answers with <IdPath>' -ForEach @(
			@{ Wrapper = 'Get-MmsBitLockerReport'; Plugin = 'BitLocker'; IdPath = 'ClientId'; Extra = @('ComplianceState', 'EncryptionPercentage', 'Disks') }
			@{ Wrapper = 'Get-MmsDriveMonitoringReport'; Plugin = 'DriveMonitoring'; IdPath = 'ClientId'; Extra = @('VolumeInfos', 'CurrentThresholdSize') }
			@{ Wrapper = 'Get-MmsMaintenanceRebootReport'; Plugin = 'MaintenanceReboot'; IdPath = 'ClientId'; Extra = @('AutoRebootState', 'EventList') }
			@{ Wrapper = 'Get-MmsEmpirumMonitoringReport'; Plugin = 'EmpirumAgentMonitoring'; IdPath = 'Report.ClientId'; Extra = @('Report.UafActive', 'EmpirumData', 'AdData') }
			@{ Wrapper = 'Get-MmsServiceInfrastructureReport'; Plugin = 'ServiceInfrastructure'; IdPath = 'ClientId'; Extra = @('Name', 'IsOnline', 'LastContact', 'LastLogonUser') }
		) {
			if (-not (Test-PluginConfigured -Name $Plugin)) {
				Set-ItResult -Skipped -Because "$Plugin is not listed in Integration.Plugins"
			}

			$rows = @(& $Wrapper -Limit 1 @script:target)
			if (0 -eq $rows.Count) {
				Set-ItResult -Skipped -Because "this server has no $Plugin data"
			}

			Assert-HasProperty -Object $rows[0] -Property (@($IdPath) + @($Extra))
		}

		It '-Limit really limits, so the suite stays fast' {
			if (-not (Test-PluginConfigured -Name 'EmpirumAgentMonitoring')) {
				Set-ItResult -Skipped -Because 'EmpirumAgentMonitoring is not listed in Integration.Plugins'
			}

			@(Get-MmsEmpirumMonitoringReport -Limit 1 @script:target).Count | Should -BeLessOrEqual 1
		}
	}

	Context 'BitLocker recovery keys' {
		BeforeEach {
			if (-not (Test-PluginConfigured -Name 'BitLocker')) {
				Set-ItResult -Skipped -Because 'BitLocker is not listed in Integration.Plugins'
			}
		}

		It 'Get-MmsBitLockerPolicy returns the global policy' {
			$policy = Get-MmsBitLockerPolicy @script:target
			if ($null -eq $policy) {
				Set-ItResult -Skipped -Because 'this server has no BitLocker policy'
			}

			$policy | Should -Not -BeNullOrEmpty
		}

		It 'Get-MmsBitLockerRecoveryKey answers with an object for a known client' {
			# Presence and type only. The key value must never reach the output
			# of a test - a failed assertion prints what it was given.
			$keys = @(Get-MmsBitLockerRecoveryKey -ClientId $script:client.Id -Source 'Ad' @script:target)
			if (0 -eq $keys.Count) {
				Set-ItResult -Skipped -Because 'no AD recovery key stored for the configured client'
			}

			$keys[0] | Should -Not -BeOfType [string] -Because 'the route answers with an object, not with the bare key'
		}

		It 'Get-MmsBitLockerRecoveryKey returns nothing countable for an unknown client' {
			# This route answers "nothing found" with the literal string null.
			# The request layer has to turn that into no output, otherwise every
			# caller has to know about it.
			@(Get-MmsBitLockerRecoveryKey -ClientId ([guid]::NewGuid()) -Source 'Ad' @script:target).Count |
				Should -Be 0
		}
	}

	Context 'Device Information plug-in' {
		BeforeEach {
			if (-not (Test-PluginConfigured -Name 'DeviceInformation')) {
				Set-ItResult -Skipped -Because 'DeviceInformation is not listed in Integration.Plugins'
			}
		}

		# The parameter sets themselves are decided during binding and need no
		# server, so they live in Unit\Get-MmsDeviceInformation.Tests.ps1. What
		# is left here is the part only a real response can answer.

		It 'the server refuses the list route without a type' {
			# This is why -Type is mandatory on the wrapper, and the only place
			# the reason can actually be checked. Sent through the transport
			# rather than the wrapper on purpose: the wrapper cannot produce this
			# request, and if the server ever stops rejecting it, the mandatory
			# parameter is the module inventing a restriction of its own.
			#
			# The pattern names the claim rather than just 'it threw': the
			# status has to be a 400 and the complaint has to be about the type.
			# A bare '*400*' would be satisfied by a port or a guid in the url,
			# which is the trap rule 11 in README.md is about. The exact wording
			# of the validation message is deliberately not pinned - a reworded
			# message is not a breaking change, a request that suddenly succeeds
			# is.
			{ Invoke-MmsApiRequest -Path '/api/DeviceInformationV2' -Query @{ type = '' } @script:target -ErrorAction Stop } |
				Should -Throw -ExpectedMessage '*HTTP 400*type*'
		}

		It 'Get-MmsDeviceInformation -Type returns rows' {
			# 'cert' and not 'Certificate'. The area names are short - 'sw',
			# 'cert', 'os', 'hw' - and an unknown one is not an error: the server
			# answers with a record that has every sub object null. Asserting only
			# on Id therefore passed for 'Certificate' exactly as it would for a
			# typo, which is the one thing this test must not do.
			$rows = @(Get-MmsDeviceInformation -Type 'cert' -Limit 1 @script:target)
			if (0 -eq $rows.Count) {
				Set-ItResult -Skipped -Because 'no device information reported on this server'
			}

			Assert-HasProperty -Object $rows[0] -Property 'Id', 'OperatingSystem'

			# The area actually asked for has to arrive, otherwise the type was
			# not understood. A client that has not inventoried yet is a skip.
			if ($null -eq $rows[0].OperatingSystem) {
				Set-ItResult -Skipped -Because 'the first record carries no operating system data yet'
			}

			Assert-HasProperty -Object $rows[0] -Property 'OperatingSystem.CertificateStores'
		}

		It 'Get-MmsDeviceInformation -ClientId returns one record for the client' {
			$record = Get-MmsDeviceInformation -ClientId $script:client.Id @script:target
			if ($null -eq $record) {
				Set-ItResult -Skipped -Because 'no device information reported for the configured client'
			}

			$record | Should -Not -BeNullOrEmpty
		}
	}

	Context 'Notification Center plug-in' {
		BeforeEach {
			if (-not (Test-PluginConfigured -Name 'NotificationCenter')) {
				Set-ItResult -Skipped -Because 'NotificationCenter is not listed in Integration.Plugins'
			}
		}

		It 'Get-MmsNotificationCenterTarget groups client ids under a name' {
			$targets = @(Get-MmsNotificationCenterTarget @script:target)
			if (0 -eq $targets.Count) {
				Set-ItResult -Skipped -Because 'this server has no notification targets'
			}

			Assert-HasProperty -Object $targets[0] -Property 'Name', 'Type', 'ClientIds'
		}

		It 'Get-MmsNotification returns notifications with their targets' {
			$notifications = @(Get-MmsNotification @script:target)
			if (0 -eq $notifications.Count) {
				Set-ItResult -Skipped -Because 'this server has no notifications'
			}

			# The examples read $_.Notification.Id and $_.Targets[].ClientId, so
			# the nesting is part of the contract, not just the field names.
			Assert-HasProperty -Object $notifications[0] -Property 'Notification.Id', 'Targets'
		}
	}

	Context 'Application Package Center' {
		BeforeEach {
			if (-not (Test-PluginConfigured -Name 'Apc')) {
				Set-ItResult -Skipped -Because 'Apc is not listed in Integration.Plugins'
			}
		}

		It 'Get-MmsApcPipeline returns pipelines with id, name and state' {
			$pipelines = @(Get-MmsApcPipeline @script:target)
			if (0 -eq $pipelines.Count) {
				Set-ItResult -Skipped -Because 'this server has no APC pipelines'
			}

			Assert-HasProperty -Object $pipelines[0] -Property 'Id', 'Name', 'Enabled'
			$pipelines[0].Id | Should -Match '^[0-9a-fA-F]{24}$' -Because 'a pipeline id is 24 hex characters, not a guid - Start-MmsApcPipeline validates that'
		}

		It 'Get-MmsApcPackageInfo returns packages with vendor, name and version' {
			$packages = @(Get-MmsApcPackageInfo -PackageType 'Depot' @script:target)
			if (0 -eq $packages.Count) {
				Set-ItResult -Skipped -Because 'no packages available in the depot'
			}

			Assert-HasProperty -Object $packages[0] -Property 'Id', 'AppName', 'AppVendor'
		}

		It 'Get-MmsApcEmpCleanupTenant returns the tenants' {
			$tenants = @(Get-MmsApcEmpCleanupTenant -All @script:target)
			if (0 -eq $tenants.Count) {
				Set-ItResult -Skipped -Because 'no Empirum tenants on this server'
			}

			$tenants[0] | Should -Not -BeNullOrEmpty
		}

		It 'Get-MmsApcPipelineRun reports a readable state name' {
			$pipelines = @(Get-MmsApcPipeline @script:target)
			if (0 -eq $pipelines.Count) {
				Set-ItResult -Skipped -Because 'this server has no APC pipelines'
			}

			$runs = @(foreach ($pipeline in $pipelines) {
					Get-MmsApcPipelineRun -PipelineId $pipeline.Id @script:target
				})
			if (0 -eq $runs.Count) {
				Set-ItResult -Skipped -Because 'no pipeline has run on this server yet'
			}

			Assert-HasProperty -Object $runs[0] -Property 'RunId', 'State', 'StartTime'

			# The numeric state is translated by the module, so an unknown value
			# from a newer server would show up as an empty name here.
			$runs[0].StateName | Should -Not -BeNullOrEmpty
		}
	}

	Context 'MMS filter' {
		It 'Get-MmsFilter returns filters and expands their criteria' {
			$filters = @(Get-MmsFilter -ExpandCriteria @script:target)
			if (0 -eq $filters.Count) {
				Set-ItResult -Skipped -Because 'no filters defined on this server'
			}

			# CriteriaObject is added by the module, Criteria is the raw json the
			# server stores. Set-MmsFilter has to strip the former again.
			Assert-HasProperty -Object $filters[0] -Property 'Id', 'Criteria', 'CriteriaObject.Name'
		}
	}
}
