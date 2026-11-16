<#
	An APC pipeline run, started and cleaned up again.

	The pipeline is named in the test configuration and has to be a harmless one
	- a download or a report, never a productive import. The suite does not pick
	one by itself: a pipeline name says nothing about what it does to a customer
	system, so that choice belongs to whoever writes the configuration.

	What is created here is the run record, and that is what is removed again.
	The side effect of the pipeline itself - a package downloaded to the server -
	is not undone, which is exactly why the configured pipeline has to be one
	where that does not matter.
#>

BeforeAll {
	. (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\MmsTestContext.ps1')
	Import-MmsApiForTest

	$script:context = Get-MmsTestContext
	$script:target = Connect-MmsTestSession -Context $script:context

	$script:createdRuns = @()
	$script:skip = $script:context.WriteSkip
	$script:pipelineId = $script:context.Write.PipelineId
	$script:package = $null

	if ($null -eq $script:skip) {
		if ([string]::IsNullOrWhiteSpace($script:pipelineId)) {
			$script:skip = 'Write.PipelineId is not set in the test configuration'
		}
		else {
			$pipeline = @(Get-MmsApcPipeline @script:target | Where-Object { $_.Id -eq $script:pipelineId })[0]
			if ($null -eq $pipeline) {
				$script:skip = "Write.PipelineId '$($script:pipelineId)' does not exist on this server"
			}
			elseif ($true -ne $pipeline.Enabled) {
				$script:skip = "the configured pipeline '$($pipeline.Name)' is disabled"
			}
			else {
				$script:pipelineName = $pipeline.Name
				$script:package = @(Get-MmsApcPackageInfo -PackageType 'Depot' -LatestVersionOnly @script:target)[0]
				if ($null -eq $script:package) {
					$script:skip = 'no package in the depot to hand to the pipeline'
				}
			}
		}
	}
}

AfterAll {
	foreach ($runId in $script:createdRuns) {
		try {
			# Cancel first: removing the record of a run that is still going
			# leaves the run itself behind.
			$run = Get-MmsApcPipelineRun -RunId $runId @script:target -ErrorAction SilentlyContinue
			if ($null -ne $run -and $null -eq $run.EndTime) {
				Stop-MmsApcPipelineRun -RunId $runId @script:target -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
			}
			Remove-MmsApcPipelineRun -RunId $runId @script:target -Confirm:$false -ErrorAction Stop | Out-Null
			Write-Host ("cleanup: removed pipeline run {0}" -f $runId)
		}
		catch {
			Write-Warning ("cleanup of pipeline run {0} failed: {1}" -f $runId, $_.Exception.Message)
		}
	}
}

Describe 'APC pipeline run' -Tag 'Write' {

	BeforeEach {
		if ($null -ne $script:skip) {
			Set-ItResult -Skipped -Because $script:skip
		}
	}

	Context 'trigger, observe, remove' {

		It 'triggers nothing under -WhatIf' {
			$runId = Start-MmsApcPipeline -PipelineId $script:pipelineId `
				-Variables @{ PackageId = $script:package.Id } `
				@script:target -WhatIf 6>$null

			$runId | Should -BeNullOrEmpty
		}

		It 'starts the configured pipeline and returns a run id' {
			$script:runId = Start-MmsApcPipeline -PipelineId $script:pipelineId `
				-Variables @{ PackageId = $script:package.Id } `
				@script:target -Confirm:$false

			$script:runId | Should -Not -BeNullOrEmpty
			$script:createdRuns += [guid]$script:runId
		}

		It 'the run is visible with the variables it was given' {
			$run = Wait-MmsApcPipelineRun -RunId $script:runId -TimeoutMinutes 3 -PollSeconds 2 -ErrorAction SilentlyContinue

			$run | Should -Not -BeNullOrEmpty
			$run.RunId | Should -Be ([guid]$script:runId)
			$run.PipelineId | Should -Be $script:pipelineId
			$run.Variables.PackageId | Should -Be $script:package.Id
		}

		It 'reports a readable end state' {
			$run = Get-MmsApcPipelineRun -RunId $script:runId @script:target

			if ($null -eq $run.EndTime) {
				Set-ItResult -Skipped -Because "the run has not finished within the timeout, last state: $($run.StateName)"
			}

			# Not asserted as FinishedSuccessfully: whether the download works
			# depends on the depot and the network, and that is not what this
			# test is about. What matters is that the module can read the state
			# back and translate the number.
			$run.StateName | Should -Not -BeNullOrEmpty
			$run.StateName | Should -Not -Be 'Unknown'
		}

		It 'has a protocol' {
			$protocol = @(Get-MmsApcPipelineProtocol -RunId $script:runId @script:target)

			if (0 -eq $protocol.Count) {
				Set-ItResult -Skipped -Because 'the run produced no protocol entries'
			}

			$protocol[0] | Should -Not -BeNullOrEmpty
		}

		It 'is not removed under -WhatIf' {
			Remove-MmsApcPipelineRun -RunId $script:runId @script:target -WhatIf 6>$null

			Get-MmsApcPipelineRun -RunId $script:runId @script:target | Should -Not -BeNullOrEmpty
		}

		It 'is gone after Remove-MmsApcPipelineRun' {
			Remove-MmsApcPipelineRun -RunId $script:runId @script:target -Confirm:$false | Out-Null

			@(Get-MmsApcPipelineRun -RunId $script:runId @script:target -ErrorAction SilentlyContinue).Count |
				Should -Be 0

			$script:createdRuns = @($script:createdRuns | Where-Object { $_ -ne [guid]$script:runId })
		}
	}
}
