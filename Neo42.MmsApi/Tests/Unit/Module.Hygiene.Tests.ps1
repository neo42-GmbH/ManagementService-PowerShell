<#
	Properties of the module that have nothing to do with a server.

	These are the checks that used to be done by hand and forgotten: encoding,
	manifest drift, complete help, and the two rules this repository lives by -
	no ad hoc Invoke-RestMethod, and nothing internal in a public repository.

	A failure here is usually a one line fix, which is exactly why it belongs in
	a test instead of in a review.
#>

BeforeDiscovery {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')

	$script:moduleRoot = Split-Path -Path (Get-MmsTestModuleManifest) -Parent

	$script:sourceFiles = Get-MmsModuleSourceFile

	$script:publicFiles = @(
		Get-ChildItem -LiteralPath (Join-Path -Path $script:moduleRoot -ChildPath 'Public') -Filter '*.ps1' -File -Recurse |
			ForEach-Object { @{ FunctionName = $_.BaseName; FullPath = $_.FullName } }
	)
}

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:moduleRoot = Split-Path -Path (Get-MmsTestModuleManifest) -Parent
	$script:manifest = Import-PowerShellDataFile -LiteralPath (Get-MmsTestModuleManifest)

	# Again, and not only in BeforeDiscovery: the cases that walk this list
	# inside an It cannot see a variable that was assigned during discovery.
	$script:sourceFiles = Get-MmsModuleSourceFile
}

Describe 'module hygiene' -Tag 'Unit' {

	Context 'every file parses' {
		It '<RelativePath>' -ForEach $sourceFiles {
			$errors = $null
			$null = [System.Management.Automation.Language.Parser]::ParseFile($FullPath, [ref]$null, [ref]$errors)

			@($errors).Count | Should -Be 0 -Because ((@($errors) | ForEach-Object { $_.Message }) -join '; ')
		}
	}

	Context 'encoding' {
		It '<RelativePath> starts with a UTF-8 BOM' -ForEach $sourceFiles {
			# Without the BOM PowerShell 5.1 reads the file as ANSI and mangles
			# every umlaut in the help.
			$bytes = [System.IO.File]::ReadAllBytes($FullPath) | Select-Object -First 3

			@($bytes) | Should -Be @(239, 187, 191)
		}

		It '<RelativePath> uses CRLF throughout' -ForEach $sourceFiles {
			$text = [System.IO.File]::ReadAllText($FullPath)
			$bareLineFeeds = ([regex]::Matches($text, '(?<!\r)\n')).Count

			$bareLineFeeds | Should -Be 0
		}

		It '<RelativePath> indents with tabs' -ForEach $sourceFiles {
			# Only indentation that starts in column one counts. A tab followed
			# by spaces is deliberate alignment, used in the help of several
			# functions to line up an enum list.
			$text = [System.IO.File]::ReadAllText($FullPath)
			$spaceIndented = ([regex]::Matches($text, '(?m)^ +\S')).Count

			$spaceIndented | Should -Be 0
		}
	}

	Context 'manifest and Public folder agree' {
		It 'exports <FunctionName>' -ForEach $publicFiles {
			$script:manifest.FunctionsToExport | Should -Contain $FunctionName
		}

		It 'has a file for every name in FunctionsToExport' {
			$onDisk = @($publicFiles | ForEach-Object { $_.FunctionName })
			$orphans = @($script:manifest.FunctionsToExport | Where-Object { $_ -notin $onDisk })

			$orphans | Should -BeNullOrEmpty -Because 'a name without a file makes the import fail on a clean machine'
		}

		It 'imports without a warning' {
			# Stream 3, not -WarningVariable: a module being imported runs with its
			# own $WarningPreference, so the drift warning of the loader reaches the
			# console but never the variable. With -WarningVariable this case stayed
			# green while the module warned - it could not fail.
			$warnings = @(Import-Module -Name (Get-MmsTestModuleManifest) -Force 3>&1 |
					Where-Object { $_ -is [System.Management.Automation.WarningRecord] })

			$warnings | Should -BeNullOrEmpty -Because "the loader reports drift between the manifest and Public\: $($warnings -join '; ')"
		}
	}

	Context 'help is complete' {
		It '<FunctionName> has a synopsis and an example' -ForEach $publicFiles {
			$help = Get-Help -Name $FunctionName -ErrorAction Stop

			$help.Synopsis.Trim() | Should -Not -BeNullOrEmpty

			# Without an .EXAMPLE block Get-Help leaves Examples at $null, and
			# @($null).Count is 1 - so counting the wrapped value alone made this
			# half of the case unable to fail. Drop the nulls before counting.
			$examples = @($help.Examples.Example | Where-Object { $null -ne $_ })
			$examples.Count | Should -BeGreaterThan 0
		}

		It '<FunctionName> describes every parameter it declares' -ForEach $publicFiles {
			# The description, not the name: Get-Help invents an entry for every
			# declared parameter whether or not a .PARAMETER block exists, so
			# comparing names can never fail. Only an empty Description tells a
			# missing block from a written one.
			#
			# -Session is exempt. It is the same parameter on every function,
			# documented once in the README, and 52 identical copies of one
			# sentence is what a reader and an agent pay for nothing.
			$command = Get-Command -Name $FunctionName
			$help = Get-Help -Name $FunctionName -ErrorAction Stop

			$described = @($help.Parameters.Parameter |
					Where-Object { -not [string]::IsNullOrWhiteSpace(($_.Description | ForEach-Object { $_.Text }) -join '') } |
					ForEach-Object { $_.Name })

			$declared = @($command.Parameters.Keys | Where-Object {
					$_ -ne 'Session' -and
					$_ -notin ([System.Management.Automation.PSCmdlet]::CommonParameters) -and
					$_ -notin ([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)
				})
			$undescribed = @($declared | Where-Object { $_ -notin $described })

			$undescribed | Should -BeNullOrEmpty -Because "these have no .PARAMETER text: $($undescribed -join ', ')"
		}
	}

	Context 'the standing rules of this repository' {
		It 'calls the transport only where it belongs' {
			# Every request goes through Invoke-MmsApiRequest. Test-MmsApiConnection
			# is the one exception: it probes the swagger document directly to tell
			# 'documentation switched off' apart from 'not allowed'.
			$allowed = @(
				'Public\Core\Invoke-MmsApiRequest.ps1'
				'Public\Core\Test-MmsApiConnection.ps1'
			)

			$offenders = @(
				Get-ChildItem -LiteralPath (Join-Path -Path $script:moduleRoot -ChildPath 'Public') -Filter '*.ps1' -File -Recurse
				Get-ChildItem -LiteralPath (Join-Path -Path $script:moduleRoot -ChildPath 'Private') -Filter '*.ps1' -File -Recurse
			) | Where-Object {
				$relative = $_.FullName.Substring($script:moduleRoot.Length + 1)
				if ($relative -in $allowed) { return $false }

				# The AST, not a regex: several helpers mention Invoke-RestMethod in
				# their help, and that is documentation, not a call.
				$ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
				$calls = $ast.FindAll({
						param ($node)
						$node -is [System.Management.Automation.Language.CommandAst] -and
						($node.GetCommandName() -in 'Invoke-RestMethod', 'Invoke-WebRequest')
					}, $true)

				@($calls).Count -gt 0
			} | ForEach-Object { $_.FullName.Substring($script:moduleRoot.Length + 1) }

			$offenders | Should -BeNullOrEmpty -Because 'an ad hoc call skips session handling, auth, error handling and -WhatIf'
		}

		It 'every function that sends a non-GET request guards it with Test-MmsShouldProcess' {
			# The behavioural proof is in Test-MmsShouldProcess.Tests.ps1. This is
			# the static counterpart, so a new endpoint is caught even before
			# someone adds a case for it there.
			#
			# Deliberately not filtered by verb: three of the five functions that
			# were found leaking a caller's -WhatIf were called Find-, Get- and
			# Test-. What decides is the method on the wire, not the name.
			$offenders = @(
				Get-ChildItem -LiteralPath (Join-Path -Path $script:moduleRoot -ChildPath 'Public') -Filter '*.ps1' -File -Recurse |
					Where-Object {
						$text = [System.IO.File]::ReadAllText($_.FullName)
						($text -match '-Method\s+(POST|PUT|PATCH|DELETE)') -and ($text -notmatch 'Test-MmsShouldProcess')
					} | ForEach-Object { $_.BaseName }
			)

			$offenders | Should -BeNullOrEmpty -Because 'a nested ShouldProcess inside Invoke-MmsApiRequest sees the module scope as its caller, so the calling script''s -WhatIf is lost'
		}

		It 'no file names the machine it was written on' {
			# The repository is a public clone. This catches the accident that
			# already happened once: a hard coded internal host in an example.
			#
			# $env:USERDOMAIN is deliberately not among them. The NetBIOS short
			# name is a handful of letters and collides with the placeholder
			# domains the examples are written with - 'CORP\PC0815' and
			# 'corp.example.com' are generic, and on a machine in a domain called
			# CORP every one of them would be reported. The FQDN, the account and
			# the computer name are specific enough to mean something.
			$needles = @(
				$env:USERDNSDOMAIN
				$env:USERNAME
				$env:COMPUTERNAME
				$env:USERPROFILE
			) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_.Length -gt 3 }

			$found = foreach ($file in $script:sourceFiles) {
				$text = [System.IO.File]::ReadAllText($file.FullPath)
				foreach ($needle in $needles) {
					if ($text -match [regex]::Escape($needle)) {
						'{0} contains {1}' -f $file.RelativePath, $needle
					}
				}
			}

			@($found) | Should -BeNullOrEmpty
		}

		It 'contains no TLS validation workaround' {
			# This file is exempt from its own rule: it has to name the patterns it
			# forbids, the same way the transport check exempts Invoke-MmsApiRequest.
			$allowed = @('Tests\Unit\Module.Hygiene.Tests.ps1')

			$found = foreach ($file in $script:sourceFiles) {
				if ($file.RelativePath -in $allowed) { continue }
				$text = [System.IO.File]::ReadAllText($file.FullPath)
				if ($text -match 'ServerCertificateValidationCallback|SkipCertificateCheck|TrustAllCertsPolicy') {
					$file.RelativePath
				}
			}

			@($found) | Should -BeNullOrEmpty
		}
	}

	Context 'the connection surface' {
		# A per call -ServerName or -ConnectionProfile carries an address
		# without a sign-in, so it would drop the credential of the active
		# session. Only Connect-MmsApi and Set-MmsConnectionProfile configure an
		# address, plus Test-MmsApiConnection, which has to work when there is
		# no session left to resolve.
		BeforeAll {
			$script:noSession = @(
				'Connect-MmsApi', 'Disconnect-MmsApi', 'Get-MmsApiSession', 'Find-MmsApiRoute',
				'Get-MmsConnectionProfile', 'Set-MmsConnectionProfile', 'Remove-MmsConnectionProfile'
			)
			$script:mayNameAnAddress = @('Connect-MmsApi', 'Set-MmsConnectionProfile', 'Test-MmsApiConnection')
			$script:surface = @(Get-Command -Module Neo42.MmsApi | ForEach-Object {
					[pscustomobject]@{ Name = $_.Name; Keys = @($_.Parameters.Keys) }
				})
		}

		It 'every endpoint function takes -Session' {
			$script:surface.Count | Should -BeGreaterThan 0
			$missing = @($script:surface |
					Where-Object { $_.Name -notin $script:noSession -and $_.Keys -notcontains 'Session' } |
					ForEach-Object { $_.Name })

			$missing | Should -BeNullOrEmpty -Because "these forward nothing: $($missing -join ', ')"
		}

		It 'only the three configuring functions name an address' {
			$offenders = @($script:surface |
					Where-Object { $_.Name -notin $script:mayNameAnAddress } |
					Where-Object { $_.Keys -contains 'ServerName' -or $_.Keys -contains 'ConnectionProfile' } |
					ForEach-Object { $_.Name })

			$offenders | Should -BeNullOrEmpty -Because "these take a per call address: $($offenders -join ', ')"
			(Get-Command 'Test-MmsApiConnection').Parameters.Keys | Should -Contain 'ServerName'
			(Get-Command 'Test-MmsApiConnection').Parameters.Keys | Should -Not -Contain 'ConnectionProfile'
		}

		It 'no function offers a bearer token' {
			# The server issues none, and WinAuthorize routes need a Windows
			# principal regardless. Add the parameter when that changes.
			$offenders = @($script:surface | Where-Object { $_.Keys -contains 'Token' } | ForEach-Object { $_.Name })

			$offenders | Should -BeNullOrEmpty -Because "these offer -Token: $($offenders -join ', ')"
		}
	}
}