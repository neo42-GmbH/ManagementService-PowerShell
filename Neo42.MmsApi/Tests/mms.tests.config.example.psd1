<#
	Template for the test environment configuration.

	Copy this file to 'mms.tests.config.psd1' next to it and fill in your own
	server. That copy is ignored by git and is NEVER generated or written by the
	test suite - it is read exactly as you wrote it. Without it only the Unit
	tests run; Integration and Write tests report themselves as skipped.

	A different path can be pointed at with the environment variable
	NEO42_MMS_TEST_CONFIG.

	No secrets belong in here. Authentication comes from the account that runs
	the tests (Windows integrated) or from a credential you pass to
	Invoke-MmsTests.ps1 -Credential.
#>
@{
	# How the tests reach the API. Either an address ...
	ServerName        = 'https://mms.lab.example:4242'

	# ... or the name of a profile from %USERPROFILE%\.neo42\mms.json.
	# When both are set, ConnectionProfile wins.
	ConnectionProfile = ''

	# Safety switch. Everything under 'Write' refuses to run unless this is $true.
	# Set it only for a server whose data you are willing to lose.
	IsLab             = $false

	Integration       = @{
		Enabled      = $true

		# A client that exists on this server. Used for the by-client report
		# reads. Leave empty to let the tests pick the first client they find.
		ClientName   = ''
		ClientDomain = ''

		# Plug-ins to check the response shape of. A plug-in that is not
		# licensed or has no data yet reports as skipped, not as a failure.
		Plugins      = @(
			'BitLocker'
			'DeviceInformation'
			'DriveMonitoring'
			'EmpirumAgentMonitoring'
			'MaintenanceReboot'
			'ServiceInfrastructure'
			'Wsus'
			'NotificationCenter'
			'Apc'
		)
	}

	Write             = @{
		Enabled                = $false

		# Client that receives the test notification. It is only written to,
		# never deleted. An unreachable client still works: the notification is
		# created and read back, IsSent simply stays false.
		NotificationClientName = ''

		# Clients this suite is allowed to DELETE. Name them only if losing
		# their report history is acceptable - a client re-registers and resends
		# its reports when its client component next contacts the server, but the
		# old history is gone for good. Empty means: delete nothing.
		DeletableClientNames   = @()

		# Pipeline that may be started. Must be a harmless one - a download or a
		# report, never a productive import. 24 hex characters, as shown by
		# Get-MmsApcPipeline.
		PipelineId             = ''
	}
}
