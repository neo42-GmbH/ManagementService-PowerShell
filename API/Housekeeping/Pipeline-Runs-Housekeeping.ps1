#Requires -Version 5
<#
.SYNOPSIS
	Deletes pipeline runs from the MMS database that exceed a given age or count per pipeline.
.DESCRIPTION
    All pipeline runs that are older than the RemoveAfterDays or exceeds the count of 
    MaximumRuns per pipeline will be removed from the database. The product automation
    history for these runs is also removed.
    Pipeline runs that were canceled before they started have neither a start nor an
    end time and are never removed by the server; they are deleted regardless of age
    and count.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER RemoveAfterDays
	The number of days after which pipeline runs are deleted in the database.
.PARAMETER MaximumRuns
    The maximum number of run per pipeline to keep in the database.
.OUTPUTS
	none
.EXAMPLE
	.\Pipeline-Runs-Housekeeping.ps1 -ServerName "https://server.domain:4242" -RemoveAfterDays 30 -MaximumRuns 4
#>
[CmdletBinding(SupportsShouldProcess)]
Param (
    [parameter(Mandatory = $true)]
    [String]
    $ServerName,
    [parameter(Mandatory = $true)]
    [int]
    $RemoveAfterDays,
    [parameter(Mandatory = $true)]
    [int]
    $MaximumRuns
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

# Get all pipelines from MMS Server. Get-MmsApcPipeline reads the documented
# route /api/apc/Pipelines and unwraps the { Success, Item, Error } envelope.
$pipelines = Get-MmsApcPipeline

foreach ($pipeline in $pipelines) {
    # Get all runs of the pipeline from the MMS Server.
    $runs = Get-MmsApcPipelineRun -PipelineId $pipeline.Id
    $count = 0;

    # Runs that never started have no StartTime; they are sorted last instead of raising an error.
    foreach ($run in ($runs | Sort-Object { if ($_.StartTime) { Get-Date $_.StartTime } } -Descending)) {
        if ($null -ne $run.StartTime -and $null -ne $run.EndTime) {
            $count++
            $age = New-TimeSpan -Start (Get-Date $run.EndTime) -End (Get-Date)
            if ($count -gt $MaximumRuns -or $age.Days -gt $RemoveAfterDays) {
                # Delete the given pipeline run from the MMS Server.
                # -Confirm:$false because this script is meant to run unattended as
                # a scheduled task. Run it once with -WhatIf to see what it would
                # delete.
                Remove-MmsApcPipelineRun -RunId $run.RunId -Confirm:$false
            }
        }
        elseif ($run.StateName -eq 'Canceled' -and $null -eq $run.EndTime) {
            # A run that is canceled while still queued never gets a start or end
            # time. It has not run anything, so it is deleted right away.
            Remove-MmsApcPipelineRun -RunId $run.RunId -Confirm:$false
        }
    }
}