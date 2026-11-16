<#
	Every route this module calls, against the swagger snapshot.

	This is the breaking change detector, and it is the reason the suite exists:
	after refreshing docs\swagger-v1.json against a new MMS version, this file
	says which wrappers a server side change has just broken - before a customer
	finds out.

	It works offline because the snapshot is part of the module. It does not
	check that a route still behaves the same way, only that it still exists with
	the same method; behaviour belongs in the Integration tests.

	The table is written out rather than derived, because a contract you can read
	is worth more than one you have to compute. It cannot drift, though: 'the
	table matches the sources' below extracts the routes from Public\ through the
	AST and compares both directions, so a new endpoint that nobody listed fails
	here immediately.

	Every route in the table has to be in the snapshot. There is no exception
	list: the module wraps published routes only, and 'the module wraps published
	routes only' below is the case that says so.
#>

BeforeDiscovery {
	# Method, route and the wrapper that calls it. Path templates use the {0}
	# form the wrappers substitute with -f, so the entries can be compared to
	# the sources character for character.
	$script:usedRoutes = @(
		@{ Method = 'POST'; Route = '/api/apc/PipelineSpecificationItem/Filtered'; Wrapper = 'Find-MmsApcPipeline' }
		@{ Method = 'GET'; Route = '/api/apc/DefaultPackage/all/{0}'; Wrapper = 'Get-MmsApcDefaultPackage' }
		@{ Method = 'GET'; Route = '/api/apc/EmpirumCleanup/CalculateSize'; Wrapper = 'Get-MmsApcEmpCleanupDirectorySize' }
		@{ Method = 'GET'; Route = '/api/apc/EmpirumCleanupJob/{0}'; Wrapper = 'Get-MmsApcEmpCleanupJob' }
		@{ Method = 'GET'; Route = '/api/apc/EmpirumCleanupJob/all'; Wrapper = 'Get-MmsApcEmpCleanupJob' }
		@{ Method = 'GET'; Route = '/api/apc/EmpirumCleanup/CleanupItems'; Wrapper = 'Get-MmsApcEmpCleanupPackageList' }
		@{ Method = 'GET'; Route = '/api/apc/EmpirumCleanup/Protocols'; Wrapper = 'Get-MmsApcEmpCleanupProtocol' }
		@{ Method = 'GET'; Route = '/api/apc/tenant'; Wrapper = 'Get-MmsApcEmpCleanupTenant' }
		@{ Method = 'GET'; Route = '/api/apc/tenant/{0}'; Wrapper = 'Get-MmsApcEmpCleanupTenant' }
		@{ Method = 'GET'; Route = '/api/apc/tenant/all'; Wrapper = 'Get-MmsApcEmpCleanupTenant' }
		@{ Method = 'GET'; Route = '/api/apc/NetworkDrive'; Wrapper = 'Get-MmsApcNetworkDrive' }
		@{ Method = 'GET'; Route = '/api/apc/NetworkDrive/{0}'; Wrapper = 'Get-MmsApcNetworkDrive' }
		@{ Method = 'GET'; Route = '/api/apc/NetworkDrive/all'; Wrapper = 'Get-MmsApcNetworkDrive' }
		@{ Method = 'GET'; Route = '/api/apc/NetworkDrive/exists'; Wrapper = 'Get-MmsApcNetworkDrive' }
		@{ Method = 'POST'; Route = '/api/apc/NetworkDrive/Files'; Wrapper = 'Get-MmsApcNetworkDriveFile' }
		@{ Method = 'GET'; Route = '/api/apc/PackageInfo/all/{0}/{1}/{2}'; Wrapper = 'Get-MmsApcPackageInfo' }
		@{ Method = 'GET'; Route = '/api/apc/PackageInfo/all/{0}/{1}/{2}/{3}/{4}'; Wrapper = 'Get-MmsApcPackageInfo' }
		@{ Method = 'GET'; Route = '/api/apc/PackageInteraction/LatestSyncJob'; Wrapper = 'Get-MmsApcPackageSyncJob' }
		@{ Method = 'GET'; Route = '/api/apc/Pipelines'; Wrapper = 'Get-MmsApcPipeline' }
		@{ Method = 'GET'; Route = '/api/apc/Pipelines/{0}'; Wrapper = 'Get-MmsApcPipeline' }
		@{ Method = 'GET'; Route = '/api/apc/PipelineProtocol/GetMany/{0}/{1}/{2}'; Wrapper = 'Get-MmsApcPipelineProtocol' }
		@{ Method = 'GET'; Route = '/api/apc/PipelineRun/{0}'; Wrapper = 'Get-MmsApcPipelineRun' }
		@{ Method = 'GET'; Route = '/api/apc/PipelineRun/GetMany/{0}'; Wrapper = 'Get-MmsApcPipelineRun' }
		@{ Method = 'GET'; Route = '/api/apc/PipelineVariable/{0}'; Wrapper = 'Get-MmsApcPipelineVariable' }
		@{ Method = 'GET'; Route = '/api/apc/PipelineVariable/all'; Wrapper = 'Get-MmsApcPipelineVariable' }
		@{ Method = 'GET'; Route = '/api/BitlockerPolicy'; Wrapper = 'Get-MmsBitLockerPolicy' }
		@{ Method = 'GET'; Route = '/api/BitlockerPolicy/{0}'; Wrapper = 'Get-MmsBitLockerPolicy' }
		@{ Method = 'GET'; Route = '/api/BitlockerAdRecoveryKey'; Wrapper = 'Get-MmsBitLockerRecoveryKey' }
		@{ Method = 'GET'; Route = '/api/BitlockerInbuiltRecoveryKey'; Wrapper = 'Get-MmsBitLockerRecoveryKey' }
		@{ Method = 'GET'; Route = '/api/BitlockerRecoveryKeyBackup'; Wrapper = 'Get-MmsBitLockerRecoveryKeyBackup' }
		@{ Method = 'GET'; Route = '/api/BitlockerRecoveryKeyBackup/{0}'; Wrapper = 'Get-MmsBitLockerRecoveryKeyBackup' }
		@{ Method = 'GET'; Route = '/api/BitlockerReportV4'; Wrapper = 'Get-MmsBitLockerReport' }
		@{ Method = 'GET'; Route = '/api/BitlockerReportV4/{0}'; Wrapper = 'Get-MmsBitLockerReport' }
		@{ Method = 'GET'; Route = '/api/Client'; Wrapper = 'Get-MmsClient' }
		@{ Method = 'GET'; Route = '/api/Client/{0}'; Wrapper = 'Get-MmsClient' }
		@{ Method = 'GET'; Route = '/api/client/{0}/{1}'; Wrapper = 'Get-MmsClient' }
		@{ Method = 'GET'; Route = '/api/DeviceInformationV2'; Wrapper = 'Get-MmsDeviceInformation' }
		@{ Method = 'GET'; Route = '/api/DeviceInformationV2/{0}'; Wrapper = 'Get-MmsDeviceInformation' }
		@{ Method = 'GET'; Route = '/api/DriveMonitoringReport'; Wrapper = 'Get-MmsDriveMonitoringReport' }
		@{ Method = 'GET'; Route = '/api/DriveMonitoringReport/{0}'; Wrapper = 'Get-MmsDriveMonitoringReport' }
		@{ Method = 'GET'; Route = '/api/EmpirumMonitoringReportV2'; Wrapper = 'Get-MmsEmpirumMonitoringReport' }
		@{ Method = 'GET'; Route = '/api/EmpirumMonitoringReportV2/{0}'; Wrapper = 'Get-MmsEmpirumMonitoringReport' }
		@{ Method = 'GET'; Route = '/api/criteriastorev3'; Wrapper = 'Get-MmsFilter' }
		@{ Method = 'GET'; Route = '/api/criteriastorev3/{0}'; Wrapper = 'Get-MmsFilter' }
		@{ Method = 'GET'; Route = '/api/CriteriaGroupEvalDuration'; Wrapper = 'Get-MmsFilterEvaluation' }
		@{ Method = 'GET'; Route = '/api/MaintenanceReportV3'; Wrapper = 'Get-MmsMaintenanceRebootReport' }
		@{ Method = 'GET'; Route = '/api/MaintenanceReportV3/{0}'; Wrapper = 'Get-MmsMaintenanceRebootReport' }
		@{ Method = 'GET'; Route = '/api/NotificationCenter/Notifications/{0}'; Wrapper = 'Get-MmsNotification' }
		@{ Method = 'GET'; Route = '/api/NotificationCenter/Notifications/All'; Wrapper = 'Get-MmsNotification' }
		@{ Method = 'GET'; Route = '/api/NotificationCenter/Target/All'; Wrapper = 'Get-MmsNotificationCenterTarget' }
		@{ Method = 'GET'; Route = '/api/TimeService/1'; Wrapper = 'Get-MmsServerTime' }
		@{ Method = 'GET'; Route = '/api/Version'; Wrapper = 'Get-MmsServerVersion' }
		@{ Method = 'GET'; Route = '/api/ServiceInfrastructureV3'; Wrapper = 'Get-MmsServiceInfrastructureReport' }
		@{ Method = 'GET'; Route = '/api/ServiceInfrastructureV3/{0}'; Wrapper = 'Get-MmsServiceInfrastructureReport' }
		@{ Method = 'GET'; Route = '/api/WsusComputerTargetV2'; Wrapper = 'Get-MmsWsusComputerTarget' }
		@{ Method = 'GET'; Route = '/api/WsusComputerTargetV2/{0}'; Wrapper = 'Get-MmsWsusComputerTarget' }
		@{ Method = 'GET'; Route = '/api/WsusUpdateSummariesPerComputerV2'; Wrapper = 'Get-MmsWsusUpdateSummary' }
		@{ Method = 'GET'; Route = '/api/WsusUpdateSummariesPerComputerV2/{0}'; Wrapper = 'Get-MmsWsusUpdateSummary' }
		@{ Method = 'POST'; Route = '/api/apc/EmpirumCleanupJob'; Wrapper = 'New-MmsApcEmpCleanupJob' }
		@{ Method = 'DELETE'; Route = '/api/apc/EmpirumCleanupJob/{0}'; Wrapper = 'Remove-MmsApcEmpCleanupJob' }
		@{ Method = 'DELETE'; Route = '/api/apc/PipelineRun/{0}'; Wrapper = 'Remove-MmsApcPipelineRun' }
		@{ Method = 'DELETE'; Route = '/api/apc/PipelineVariable/{0}'; Wrapper = 'Remove-MmsApcPipelineVariable' }
		@{ Method = 'DELETE'; Route = '/api/ServiceInfrastructureV3/{0}'; Wrapper = 'Remove-MmsClient' }
		@{ Method = 'DELETE'; Route = '/api/NotificationCenter/Notifications/{0}'; Wrapper = 'Remove-MmsNotification' }
		@{ Method = 'DELETE'; Route = '/api/NotificationCenter/NotificationTarget/Pending'; Wrapper = 'Remove-MmsPendingNotification' }
		@{ Method = 'POST'; Route = '/api/StoreableNotification'; Wrapper = 'Send-MmsClientMessage' }
		@{ Method = 'POST'; Route = '/api/NotificationCenter/Notifications'; Wrapper = 'Send-MmsClientNotification' }
		@{ Method = 'GET'; Route = '/api/criteriastorev3/cancreate/{0}'; Wrapper = 'New-MmsFilter' }
		@{ Method = 'GET'; Route = '/api/criteriastorev3/create/{0}'; Wrapper = 'New-MmsFilter' }
		@{ Method = 'POST'; Route = '/api/criteriastorev3'; Wrapper = 'New-MmsFilter' }
		@{ Method = 'POST'; Route = '/api/criteriastorev3'; Wrapper = 'Set-MmsFilter' }
		@{ Method = 'POST'; Route = '/api/apc/EmpirumCleanup/StartEmpirumCleanupJob'; Wrapper = 'Start-MmsApcEmpCleanupJob' }
		@{ Method = 'POST'; Route = '/api/apc/PackageInteraction/StartSync'; Wrapper = 'Start-MmsApcPackageSync' }
		@{ Method = 'POST'; Route = '/api/apc/PipelineInteraction/run'; Wrapper = 'Start-MmsApcPipeline' }
		@{ Method = 'POST'; Route = '/api/apc/PipelineInteraction/cancel'; Wrapper = 'Stop-MmsApcPipelineRun' }
		@{ Method = 'POST'; Route = '/api/apc/EmpirumCleanup/CheckForDuplicates'; Wrapper = 'Test-MmsApcEmpCleanupDuplicates' }
		@{ Method = 'GET'; Route = '/api/TimeService/1'; Wrapper = 'Test-MmsApiConnection' }
	)

	# There is no exception list. The module wraps only routes that the server
	# publishes through swagger, so every entry above has to be in the snapshot
	# and 'no wrapper calls an unpublished route' below asserts it as a set.
	$script:documentedRoutes = $script:usedRoutes
}

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:moduleRoot = Split-Path -Path (Get-MmsTestModuleManifest) -Parent
	$script:snapshotPath = Join-Path -Path $script:moduleRoot -ChildPath 'docs\swagger-v1.json'

	function Get-RouteFromSource {
		<#
			Pulls the route literals out of the wrapper sources through the AST.

			The AST rather than a regex, for two reasons: the routes named in
			comment based help are not AST nodes and are therefore ignored, and a
			path handed to Invoke-MmsApiRequest through a variable is still found,
			because the literal it was assigned lives in the same file.
		#>
		[CmdletBinding()]
		[OutputType([pscustomobject])]
		param ()

		foreach ($file in (Get-ChildItem -LiteralPath (Join-Path -Path $script:moduleRoot -ChildPath 'Public') -Filter '*.ps1' -File -Recurse)) {
			$ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

			$routes = @(
				$ast.FindAll({
						param ($node)
						($node -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and
						($node.Value -match '^/(api|docs)/')
					}, $true) | ForEach-Object { $_.Value } | Sort-Object -Unique
			)

			foreach ($route in $routes) {
				[pscustomobject]@{ Wrapper = $file.BaseName; Route = $route }
			}
		}
	}
}

Describe 'documented API surface' -Tag 'Unit' {

	Context 'the snapshot itself' {
		It 'is present next to the module' {
			$script:snapshotPath | Should -Exist
		}

		It 'carries the version of the server it came from' {
			$metaPath = Join-Path -Path (Split-Path -Path $script:snapshotPath -Parent) -ChildPath 'swagger-v1.meta.json'
			$metaPath | Should -Exist

			$meta = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
			$meta.ServerVersion | Should -Not -BeNullOrEmpty
		}

		It 'names no real host and no account - this repository is public' {
			# Assert on the extracted value, never by piping the whole document
			# into Should: a failure would print 170 kB of swagger.
			$document = Get-Content -LiteralPath $script:snapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json
			$metaPath = Join-Path -Path (Split-Path -Path $script:snapshotPath -Parent) -ChildPath 'swagger-v1.meta.json'
			$meta = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json

			# The host is replaced with a placeholder when the snapshot is refreshed.
			$document.host | Should -Be 'server.domain:4242'

			# Neither the machine nor the account that fetched it belongs in here.
			@($meta.PSObject.Properties.Name) | Should -Not -Contain 'SourceHost'
			@($meta.PSObject.Properties.Name) | Should -Not -Contain 'FetchedBy'
		}
	}

	Context 'the table matches the sources' {
		# Without these two the table is a document that slowly stops being true.
		It 'lists every route the wrappers call' {
			$listed = @($usedRoutes | ForEach-Object { '{0}  {1}' -f $_.Wrapper, $_.Route })
			$inSource = @(Get-RouteFromSource | ForEach-Object { '{0}  {1}' -f $_.Wrapper, $_.Route })

			$unlisted = @($inSource | Where-Object { $_ -notin $listed })

			$unlisted | Should -BeNullOrEmpty -Because 'a new endpoint has to be added to the table in this file, otherwise nothing tells you when the server drops it'
		}

		It 'lists no route that no wrapper calls any more' {
			$listed = @($usedRoutes | ForEach-Object { '{0}  {1}' -f $_.Wrapper, $_.Route })
			$inSource = @(Get-RouteFromSource | ForEach-Object { '{0}  {1}' -f $_.Wrapper, $_.Route })

			$stale = @($listed | Where-Object { $_ -notin $inSource })

			$stale | Should -BeNullOrEmpty -Because 'a leftover entry makes the table look like it covers more than it does'
		}
	}

	Context 'every route the module calls still exists' {
		It '<Method> <Route> (<Wrapper>)' -ForEach $documentedRoutes {
			$documented = InModuleScope Neo42.MmsApi -Parameters @{ M = $Method; P = $Route } {
				param ($M, $P)
				# The template is checked as a concrete path, exactly the way a
				# wrapper calls it, so the template matching is covered too.
				$concrete = $P -replace '\{\d+\}', '00000000-0000-0000-0000-000000000000'
				Test-MmsDocumentedRoute -Method $M -Path $concrete
			}

			$documented | Should -BeTrue -Because 'a route that vanished from swagger breaks this wrapper on the next MMS update'
		}
	}

	Context 'the module wraps published routes only' {
		# The rule, as one case rather than as an exception list: a wrapper may
		# only call a route the server publishes through swagger. The case above
		# says the same thing per route, but this one fails once and names every
		# offender at the same time - which is what someone who just added a
		# wrapper on a hidden route needs to read.
		#
		# There is deliberately no way to register an exception here. A capability
		# the published surface does not offer is out of scope for this module;
		# it is not something a wrapper plus a warning can make supportable.
		It 'calls no route that swagger does not publish' {
			$unpublished = @(
				foreach ($entry in $usedRoutes) {
					$documented = InModuleScope Neo42.MmsApi -Parameters @{ M = $entry.Method; P = $entry.Route } {
						param ($M, $P)
						$concrete = $P -replace '\{\d+\}', '00000000-0000-0000-0000-000000000000'
						Test-MmsDocumentedRoute -Method $M -Path $concrete
					}

					if ($documented -ne $true) {
						'{0} {1} ({2})' -f $entry.Method, $entry.Route, $entry.Wrapper
					}
				}
			)

			$unpublished | Should -BeNullOrEmpty -Because 'only routes published through swagger are in scope for this module - a capability the published surface does not offer cannot be wrapped here'
		}
	}
}
