<#
	Which server a call ends up on, and under which identity.

	This is the one place in the module that decides precedence. There are three
	sources and only the last of them carries an address without a sign-in, so
	the failure this file used to guard against - an address-only parameter
	silently dropping a Connect-MmsApi -Credential - can no longer be expressed.
	The tests that remain pin that down: a session is handed through untouched,
	and nothing reaches past it.

	Everything that could reach outside the test is redirected first:
	NEO42_MMS_CONFIG to a temporary file, and the module session is set through
	InModuleScope instead of a real Connect-MmsApi.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:sandbox = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('mms-tests-' + [guid]::NewGuid())
	New-Item -ItemType Directory -Path $script:sandbox -Force | Out-Null

	$script:previousConfig = $env:NEO42_MMS_CONFIG
	$env:NEO42_MMS_CONFIG = Join-Path -Path $script:sandbox -ChildPath 'mms.json'

	function Set-TestSession {
		param ([string] $ServerName, [string] $AuthMode = 'Windows', [pscredential] $Credential)

		InModuleScope Neo42.MmsApi -Parameters @{ Address = $ServerName; Mode = $AuthMode; Cred = $Credential } {
			param ($Address, $Mode, $Cred)
			$script:MmsSession = New-MmsApiSessionObject -ServerName $Address -AuthMode $Mode -Credential $Cred -Source 'Session'
		}
	}

	function Clear-TestSession {
		InModuleScope Neo42.MmsApi { $script:MmsSession = $null }
	}

	function Resolve-TestTarget {
		param ([hashtable] $Parameters = @{})

		InModuleScope Neo42.MmsApi -Parameters @{ Splat = $Parameters } {
			param ($Splat)
			Resolve-MmsApiSession @Splat
		}
	}
}

AfterAll {
	Clear-TestSession
	$env:NEO42_MMS_CONFIG = $script:previousConfig
	Remove-Item -LiteralPath $script:sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-MmsApiSession' -Tag 'Unit' {

	BeforeEach {
		Clear-TestSession
		Remove-Item -LiteralPath $env:NEO42_MMS_CONFIG -Force -ErrorAction SilentlyContinue
	}

	Context 'precedence' {
		It 'takes -Session before everything else' {
			Set-TestSession -ServerName 'https://active.invalid'
			Set-MmsConnectionProfile -Name 'unit' -ServerName 'https://profile.invalid' -SetAsDefault -Confirm:$false | Out-Null
			$explicit = InModuleScope Neo42.MmsApi { New-MmsApiSessionObject -ServerName 'https://explicit.invalid' }

			(Resolve-TestTarget @{ Session = $explicit }).ServerName | Should -Be 'https://explicit.invalid'
		}

		It 'takes the active session before the default profile' {
			Set-TestSession -ServerName 'https://active.invalid'
			Set-MmsConnectionProfile -Name 'unit' -ServerName 'https://profile.invalid' -SetAsDefault -Confirm:$false | Out-Null

			(Resolve-TestTarget).ServerName | Should -Be 'https://active.invalid'
		}

		It 'falls back to the default profile last' {
			Set-MmsConnectionProfile -Name 'unit' -ServerName 'https://profile.invalid' -SetAsDefault -Confirm:$false | Out-Null

			$resolved = Resolve-TestTarget
			$resolved.ServerName | Should -Be 'https://profile.invalid'
			$resolved.Source | Should -Be 'DefaultProfile'
		}

		It 'explains how to connect when nothing is known' {
			{ Resolve-TestTarget } | Should -Throw -ExpectedMessage '*Connect-MmsApi*'
		}
	}

	Context 'the sign-in travels with the session' {
		# The case this module is built around: Connect-MmsApi -Credential, then
		# a script that just calls wrappers. There is no address-only parameter
		# left that could reach past the session, so the credential cannot be
		# replaced by the logged on user on the way to a request.
		It 'keeps the credential of the active session' {
			$credential = New-Object System.Management.Automation.PSCredential(
				'EXAMPLE\svc-mms',
				(ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force))
			Set-TestSession -ServerName 'https://same.invalid' -AuthMode 'Credential' -Credential $credential
			Set-MmsConnectionProfile -Name 'unit' -ServerName 'https://profile.invalid' -SetAsDefault -Confirm:$false | Out-Null

			$resolved = Resolve-TestTarget

			$resolved.ServerName | Should -Be 'https://same.invalid'
			$resolved.AuthMode | Should -Be 'Credential'
			$resolved.Credential.UserName | Should -Be 'EXAMPLE\svc-mms'
		}

		It 'opens the default profile as the logged on Windows user' {
			Set-MmsConnectionProfile -Name 'unit' -ServerName 'https://profile.invalid' -SetAsDefault -Confirm:$false | Out-Null

			$resolved = Resolve-TestTarget

			$resolved.AuthMode | Should -Be 'Windows'
			$resolved.Credential | Should -BeNullOrEmpty
		}
	}

	Context 'rejected input' {
		It 'refuses an object that is not a session' {
			{ Resolve-TestTarget @{ Session = [pscustomobject]@{ Nope = $true } } } |
				Should -Throw -ExpectedMessage '*not an MMS session*'
		}
	}
}
