<#
	Shared helpers for the Neo42.MmsApi test suite.

	Dot-source this from the BeforeAll of a test file:

		. (Join-Path $PSScriptRoot '..\TestHelpers\MmsTestContext.ps1')

	Everything here is deliberately free of Pester calls, so it can also be used
	interactively while writing a test.
#>

function Get-MmsTestModuleManifest {
	<#
	.SYNOPSIS
		Path of the module manifest under test.
	.DESCRIPTION
		Always the copy in this repository, never an installed one - a test has
		to state what it tested.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	return (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi.psd1')).ProviderPath
}

function Get-MmsModuleSourceFile {
	<#
	.SYNOPSIS
		Every source file of the module, ready for a -ForEach table.
	.DESCRIPTION
		Module.Hygiene.Tests.ps1 needs this list twice: at discovery time to build
		one case per file, and again in BeforeAll, because a variable assigned in
		BeforeDiscovery is NOT visible inside an It. Two cases that iterated the
		discovery variable at run time therefore looped over nothing and could not
		fail - see rule 7 in README.md.

		The local test configuration is left out: it is not part of the module, it
		is gitignored, and it is the one file that is supposed to name a concrete
		server.
	.OUTPUTS
		Hashtable with RelativePath and FullPath, one per file.
	#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param ()

	$root = Split-Path -Path (Get-MmsTestModuleManifest) -Parent

	return @(
		Get-ChildItem -LiteralPath $root -File -Recurse |
			Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' -and $_.Name -ne 'mms.tests.config.psd1' } |
			ForEach-Object { @{ RelativePath = $_.FullName.Substring($root.Length + 1); FullPath = $_.FullName } }
	)
}

function Import-MmsApiForTest {
	<#
	.SYNOPSIS
		Imports the module under test.
	.DESCRIPTION
		-Force so an edited file is picked up between runs. The manifest path is
		used rather than the module name, so an installed Neo42.MmsApi cannot
		shadow the working copy.
	#>
	[CmdletBinding()]
	[OutputType([void])]
	param ()

	Import-Module -Name (Get-MmsTestModuleManifest) -Force -ErrorAction Stop
}

function Get-MmsTestConfigPath {
	<#
	.SYNOPSIS
		Path of the hand written test environment configuration.
	.DESCRIPTION
		NEO42_MMS_TEST_CONFIG wins, otherwise mms.tests.config.psd1 in the Tests
		folder. The file is never created here: a missing file means 'Integration
		and Write tests do not apply on this machine'.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	if (-not [string]::IsNullOrWhiteSpace($env:NEO42_MMS_TEST_CONFIG)) {
		return $env:NEO42_MMS_TEST_CONFIG
	}

	return (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'mms.tests.config.psd1')
}

function Connect-MmsTestSession {
	<#
	.SYNOPSIS
		Opens the session the Integration and Write suites run against.
	.DESCRIPTION
		The wrappers take no address, so a suite connects once here and splats
		@{ Session = ... } afterwards. Returns an empty hashtable when there is
		nothing to connect to, so the file stays loadable and its tests skip.

		A failed connect writes the reason back into the context, which makes
		every It skip. Without that an empty splat would fall through to the
		DefaultProfile of whoever runs the suite - a green run against a
		different server than the configuration names.
	.OUTPUTS
		Hashtable, to be splatted into the wrappers.
	#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[Parameter(Mandatory = $true)]
		[psobject]
		$Context
	)

	if ($null -ne $Context.IntegrationSkip -or 0 -eq $Context.Target.Count) {
		return @{}
	}

	$target = $Context.Target
	try {
		return @{ Session = (Connect-MmsApi @target -PassThru) }
	}
	catch {
		$reason = "Connect-MmsApi failed for $($Context.ServerLabel): $($_.Exception.Message)"
		$Context | Add-Member -NotePropertyName 'IntegrationSkip' -NotePropertyValue $reason -Force
		$Context | Add-Member -NotePropertyName 'WriteSkip' -NotePropertyValue $reason -Force
		Write-Warning $reason
		return @{}
	}
}

function Get-MmsTestContext {
	<#
	.SYNOPSIS
		Reads the test environment configuration and reports what may run.
	.DESCRIPTION
		Returns a context object even when there is no configuration, so a test
		file can always ask 'may I run, and if not, why not' without a try/catch.

		The configuration is read as written. Nothing is defaulted into it that
		would silently point a test at a different server, and nothing is ever
		written back.
	.OUTPUTS
		PSCustomObject.
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param ()

	$path = Get-MmsTestConfigPath
	$example = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'mms.tests.config.example.psd1'

	$context = [ordered]@{
		ConfigPath      = $path
		HasConfig       = $false
		ConfigError     = $null
		Target          = @{}
		ServerLabel     = $null
		IsLab           = $false
		Integration     = @{ Enabled = $false }
		Write           = @{ Enabled = $false }
		IntegrationSkip = "no test configuration at '$path' - copy '$example' and fill it in"
		WriteSkip       = "no test configuration at '$path' - copy '$example' and fill it in"
	}

	if (-not (Test-Path -LiteralPath $path)) {
		return [pscustomobject]$context
	}

	try {
		$config = Import-PowerShellDataFile -LiteralPath $path -ErrorAction Stop
	}
	catch {
		$context['ConfigError'] = $_.Exception.Message
		$context['IntegrationSkip'] = "test configuration '$path' is not a valid .psd1: $($_.Exception.Message)"
		$context['WriteSkip'] = $context['IntegrationSkip']
		return [pscustomobject]$context
	}

	$context['HasConfig'] = $true

	# A profile name is more specific than a bare address, so it wins.
	if (-not [string]::IsNullOrWhiteSpace($config.ConnectionProfile)) {
		$context['Target'] = @{ ConnectionProfile = $config.ConnectionProfile }
		$context['ServerLabel'] = "profile '$($config.ConnectionProfile)'"
	}
	elseif (-not [string]::IsNullOrWhiteSpace($config.ServerName)) {
		$context['Target'] = @{ ServerName = $config.ServerName }
		$context['ServerLabel'] = $config.ServerName
	}

	$context['IsLab'] = ($true -eq $config.IsLab)
	if ($null -ne $config.Integration) { $context['Integration'] = $config.Integration }
	if ($null -ne $config.Write) { $context['Write'] = $config.Write }

	# Integration: needs a target and an explicit Enabled.
	$context['IntegrationSkip'] = $null
	if (0 -eq $context['Target'].Count) {
		$context['IntegrationSkip'] = "neither ServerName nor ConnectionProfile is set in '$path'"
	}
	elseif ($true -ne $context['Integration'].Enabled) {
		$context['IntegrationSkip'] = "Integration.Enabled is not set to true in '$path'"
	}

	# Write: everything Integration needs, plus the lab switch. Two independent
	# switches on purpose - forgetting one must not be enough to change data.
	$context['WriteSkip'] = $context['IntegrationSkip']
	if ($null -eq $context['WriteSkip']) {
		if ($true -ne $context['IsLab']) {
			$context['WriteSkip'] = "IsLab is not set to true in '$path' - write tests refuse to touch a server that is not declared a lab"
		}
		elseif ($true -ne $context['Write'].Enabled) {
			$context['WriteSkip'] = "Write.Enabled is not set to true in '$path'"
		}
	}

	return [pscustomobject]$context
}
