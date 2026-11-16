<#
.SYNOPSIS
	Invokes a pipeline with the given ID and waits for it to complete.
.DESCRIPTION
	Invokes a pipeline with the given ID and waits for it to complete.
    The pipeline will be triggered with the given variables.
    The script will wait for the pipeline to complete for 10 minutes.
    If the pipeline does not complete within 10 minutes, the script will exit with an error.
    This example is constructed to trigger a pipeline with a network drive ID and path.

    Important: The user that triggers the pipeline must be member of the "Neo42MgmtSvcAdmins" local group on the neo42 Management Service server.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER PipelineID
    The ID of the pipeline to trigger. It must be a valid pipeline ID with 24 characters.
    It can be obtained from the URL when opening the pipeline in the neo42 Management Service.
.PARAMETER NetworkDriveID
    The network drive ID that should be given to the pipeline as phase variable.
    The ID is a guid and can be obtained from the URL when opening the file scanner in the neo42 Management Service.
.PARAMETER NetworkDrivePath
    The UNC path on the network drive that should be given to the pipeline as phase variable.
    Must be a valid UNC path equal to the path that the Management Service can access.
.OUTPUTS
	none
.NOTES
	Version:        1.0
	Author:         neo42 GmbH
	Creation Date:  20.12.2024
	Purpose/Change: Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Invoke-PipelineWithVariables.ps1 -ServerName "https://server.domain:4242" -PipelineID "5f9b1b1b1b1b1b1b1b1b1b1b" -NetworkDriveID "1b1b1b1b-1b1b-1b1b-1b1b-1b1b1b1b1b1b" -NetworkDrivePath "\\server\share\file.txt"
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [string]
    $ServerName,
    [Parameter(Mandatory = $true)]
    [ValidateCount(24, 24)]
    [string]
    $PipelineID,
    [Parameter(Mandatory = $true)]
    [guid]
    $NetworkDriveID,
    [Parameter(Mandatory = $true)]
    [string]
    $NetworkDrivePath = "\\some\where"
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

Write-Host "Triggering pipeline [$PipelineID] for file [$NetworkDrivePath]"

# These are <Phase> variables that will be sent to the pipeline. All variables
# must be defined in the pipeline.
$variables = @{
    NetworkDriveId       = $NetworkDriveID
    NetworkDriveFilePath = $NetworkDrivePath
}

# -Confirm:$false keeps this script non interactive. -WhatIf still works and
# shows the request without triggering anything.
$runID = Start-MmsApcPipeline -PipelineId $PipelineID -Variables $variables -Confirm:$false
if ($null -eq $runID) {
    # Nothing was triggered, for example because the script ran with -WhatIf.
    return
}

# Wait-MmsApcPipelineRun polls until the run has an EndTime and translates the
# numeric state into the readable StateName.
$pipelineRun = Wait-MmsApcPipelineRun -RunId $runID -TimeoutMinutes 10

if ($null -ne $pipelineRun.EndTime) {
    Write-Host "Pipeline for file [$NetworkDrivePath] completed with state [$($pipelineRun.StateName)]."
    exit 0
}

Write-Error "Pipeline [$PipelineID] did not complete within 10 minutes."
