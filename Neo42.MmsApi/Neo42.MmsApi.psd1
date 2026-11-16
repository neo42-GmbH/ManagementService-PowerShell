@{
	RootModule        = 'Neo42.MmsApi.psm1'
	ModuleVersion     = '1.0.0'
	GUID              = 'a7f3c1de-9b42-4c68-8f10-2d6e5b7a4c91'
	Author            = 'neo42 GmbH'
	CompanyName       = 'neo42 GmbH'
	Copyright         = '(c) neo42 GmbH. All rights reserved.'
	Description       = 'PowerShell client for the REST API of the neo42 Management Service (MMS). Covers the core API plus the plug-ins used by the example scripts of this repository. Connection profiles live outside the module in %USERPROFILE%\.neo42\mms.json; credentials are never stored.'
	PowerShellVersion = '5.1'

	# One module, not one per plug-in: every function shares the session created
	# by Connect-MmsApi, and a session cannot be shared across module scopes.
	# The plug-in split lives in the noun (Get-MmsApc*, Get-MmsBitLocker*, ...)
	# and in the subfolders of Public\, so
	#   Get-Command -Module Neo42.MmsApi -Noun MmsBitLocker*
	# gives the same grouping without the packaging cost.
	FunctionsToExport = @(
		# Core - session, request pipeline, route lookup, profiles
		'Connect-MmsApi',
		'Disconnect-MmsApi',
		'Get-MmsApiSession',
		'Test-MmsApiConnection',
		'Invoke-MmsApiRequest',
		'Find-MmsApiRoute',
		'Get-MmsConnectionProfile',
		'Set-MmsConnectionProfile',
		'Remove-MmsConnectionProfile',
		# MMS information
		'Get-MmsServerVersion',
		'Get-MmsServerTime',
		# Clients - the join key of every plug-in report
		'Get-MmsClient',
		'Remove-MmsClient',
		# MMS filter (criteria store, dynamic computer groups)
		'Get-MmsFilter',
		'Get-MmsFilterEvaluation',
		'New-MmsFilter',
		'Set-MmsFilter',
		# Application Package Center - Empirum cleanup
		'Get-MmsApcEmpCleanupTenant',
		'Get-MmsApcEmpCleanupPackageList',
		'Get-MmsApcEmpCleanupJob',
		'New-MmsApcEmpCleanupJob',
		'Start-MmsApcEmpCleanupJob',
		'Remove-MmsApcEmpCleanupJob',
		'Test-MmsApcEmpCleanupDuplicates',
		'Get-MmsApcEmpCleanupProtocol',
		'Get-MmsApcEmpCleanupDirectorySize',
		# Application Package Center - pipelines
		'Get-MmsApcPipeline',
		'Find-MmsApcPipeline',
		'Start-MmsApcPipeline',
		'Stop-MmsApcPipelineRun',
		'Get-MmsApcPipelineRun',
		'Wait-MmsApcPipelineRun',
		'Remove-MmsApcPipelineRun',
		'Get-MmsApcPipelineProtocol',
		'Get-MmsApcPipelineVariable',
		'Remove-MmsApcPipelineVariable',
		# Application Package Center - network drives and packages
		'Get-MmsApcNetworkDrive',
		'Get-MmsApcNetworkDriveFile',
		'Get-MmsApcPackageInfo',
		'Get-MmsApcDefaultPackage',
		'Get-MmsApcPackageSyncJob',
		'Start-MmsApcPackageSync',
		# BitLocker plug-in
		'Get-MmsBitLockerReport',
		'Get-MmsBitLockerPolicy',
		'Get-MmsBitLockerRecoveryKey',
		'Get-MmsBitLockerRecoveryKeyBackup',
		# Device Information plug-in
		'Get-MmsDeviceInformation',
		# Drive Monitoring plug-in
		'Get-MmsDriveMonitoringReport',
		# Empirum Agent Monitoring plug-in
		'Get-MmsEmpirumMonitoringReport',
		# Maintenance Reboot plug-in
		'Get-MmsMaintenanceRebootReport',
		# Service Infrastructure plug-in
		'Get-MmsServiceInfrastructureReport',
		# WSUS plug-in
		'Get-MmsWsusComputerTarget',
		'Get-MmsWsusUpdateSummary',
		# Notification Center plug-in
		'Get-MmsNotificationCenterTarget',
		'Send-MmsClientNotification',
		'Get-MmsNotification',
		'Remove-MmsNotification',
		'Remove-MmsPendingNotification',
		# Notification Service plug-in
		'Send-MmsClientMessage'
	)
	CmdletsToExport   = @()
	VariablesToExport = @()
	AliasesToExport   = @()
	PrivateData       = @{
		PSData = @{
			Tags       = @('neo42', 'MMS', 'ManagementService', 'APC', 'REST', 'API', 'Windows')
			ProjectUri = 'https://github.com/neo42-GmbH/ManagementService-PowerShell'
		}
	}
}
