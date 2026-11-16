<#
	The profile store outside the module.

	Two things are worth guarding here. First the promise that nothing secret is
	ever written to disk - that is a documented property of this module, not a
	detail. Second the small edge cases of deleting a profile, because they only
	show up on a machine that has more than one server configured.

	The whole test runs against a temporary configuration file, so the real
	%USERPROFILE%\.neo42\mms.json is never touched.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:sandbox = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('mms-tests-' + [guid]::NewGuid())
	New-Item -ItemType Directory -Path $script:sandbox -Force | Out-Null

	$script:previousConfig = $env:NEO42_MMS_CONFIG
	$script:configPath = Join-Path -Path $script:sandbox -ChildPath 'mms.json'
	$env:NEO42_MMS_CONFIG = $script:configPath
}

AfterAll {
	$env:NEO42_MMS_CONFIG = $script:previousConfig
	Remove-Item -LiteralPath $script:sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'MMS connection profiles' -Tag 'Unit' {

	BeforeEach {
		Remove-Item -LiteralPath $script:configPath -Force -ErrorAction SilentlyContinue
	}

	Context 'lifecycle' {
		It 'stores a normalised address and reads it back' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -Description 'Lab' -Confirm:$false | Out-Null

			$entry = Get-MmsConnectionProfile -Name 'Lab'
			$entry.ServerName | Should -Be 'https://lab.invalid:4242'
			$entry.Description | Should -Be 'Lab'
		}

		It 'makes the first profile the default without being asked' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -Confirm:$false | Out-Null

			(Get-MmsConnectionProfile -Name 'Lab').IsDefault | Should -BeTrue
		}

		It 'moves the default on request' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -Confirm:$false | Out-Null
			Set-MmsConnectionProfile -Name 'Test' -ServerName 'test.invalid:4242' -SetAsDefault -Confirm:$false | Out-Null

			(Get-MmsConnectionProfile -Name 'Test').IsDefault | Should -BeTrue
			(Get-MmsConnectionProfile -Name 'Lab').IsDefault | Should -BeFalse
		}

		It 'survives a description with umlauts' {
			# UTF-8 round trip through the json file. Under PS 5.1 a missing
			# encoding turns this into mojibake.
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -Description 'Kundentestsystem für Übergaben' -Confirm:$false | Out-Null

			(Get-MmsConnectionProfile -Name 'Lab').Description | Should -Be 'Kundentestsystem für Übergaben'
		}

		It 'overwrites an existing profile instead of duplicating it' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'old.invalid:4242' -Confirm:$false | Out-Null
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'new.invalid:4242' -Confirm:$false | Out-Null

			@(Get-MmsConnectionProfile).Count | Should -Be 1
			(Get-MmsConnectionProfile -Name 'Lab').ServerName | Should -Be 'https://new.invalid:4242'
		}
	}

	Context 'removal' {
		It 'hands the default over to a remaining profile' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -SetAsDefault -Confirm:$false | Out-Null
			Set-MmsConnectionProfile -Name 'Test' -ServerName 'test.invalid:4242' -Confirm:$false | Out-Null

			Remove-MmsConnectionProfile -Name 'Lab' -Confirm:$false

			@(Get-MmsConnectionProfile).Count | Should -Be 1
			(Get-MmsConnectionProfile -Name 'Test').IsDefault | Should -BeTrue
		}

		It 'leaves no default behind when the last profile goes' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -SetAsDefault -Confirm:$false | Out-Null

			Remove-MmsConnectionProfile -Name 'Lab' -Confirm:$false

			@(Get-MmsConnectionProfile).Count | Should -Be 0
			(Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json).DefaultProfile | Should -BeNullOrEmpty
		}

		It 'warns instead of failing for a profile that is not there' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -Confirm:$false | Out-Null

			$warnings = @()
			Remove-MmsConnectionProfile -Name 'Ghost' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue

			$warnings.Count | Should -BeGreaterThan 0
			@(Get-MmsConnectionProfile).Count | Should -Be 1
		}

		It 'names the known profiles when asked for an unknown one' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -Confirm:$false | Out-Null

			{ Get-MmsConnectionProfile -Name 'Ghost' } | Should -Throw -ExpectedMessage '*Lab*'
		}
	}

	Context 'nothing secret reaches the disk' {
		It 'writes only name, address and description' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -Description 'Lab' -Confirm:$false | Out-Null

			$stored = (Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json).Profiles.Lab
			@($stored.PSObject.Properties.Name) | Should -Be @('ServerName', 'Description')
		}

		It 'has no property that looks like a secret' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -Confirm:$false | Out-Null

			$raw = Get-Content -LiteralPath $script:configPath -Raw
			$raw | Should -Not -Match '(?i)(password|credential|token|secret)'
		}
	}

	Context 'compatibility with files written by earlier builds' {
		It 'still reads the old BaseUri key' {
			# The key was renamed to ServerName. An existing mms.json must keep
			# working, otherwise an update silently loses every profile.
			$legacy = [pscustomobject]@{
				DefaultProfile = 'Old'
				Profiles       = [pscustomobject]@{
					Old = [pscustomobject]@{ BaseUri = 'https://legacy.invalid:4242'; Description = 'written by an earlier build' }
				}
			}
			$legacy | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:configPath -Encoding UTF8

			(Get-MmsConnectionProfile -Name 'Old').ServerName | Should -Be 'https://legacy.invalid:4242'
		}
	}

	Context 'write protection' {
		It 'creates nothing under -WhatIf' {
			Set-MmsConnectionProfile -Name 'Lab' -ServerName 'lab.invalid:4242' -WhatIf 6>$null

			Test-Path -LiteralPath $script:configPath | Should -BeFalse
		}
	}
}
