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
	Purpose/Change: Initial release
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

$RequestHeaders = @{
    'Accept'       = 'application/json'
    'Content-Type' = 'application/json'
    'X-Neo42-Auth' = 'Admin'
}


Write-Host "Triggering pipeline [$PipelineID] for file [$NetworkDrivePath]"
$requestBody = @{
    PipelineId = $PipelineID
    Variables  = @{
        # These are <Phase> variables that will be sent to the pipeline. All variables must be defined in the pipeline.
        NetworkDriveId       = $NetworkDriveID
        NetworkDriveFilePath = $NetworkDrivePath
    }
}

$runID = Invoke-RestMethod -Headers $RequestHeaders -UseDefaultCredentials -Method Post -Uri "$ServerName/api/apc/PipelineInteraction/run" -Body ($requestBody | ConvertTo-Json) -ErrorAction Stop

$pipelineRunState = @{
    0  = "None"
    1  = "Queued"
    2  = "Started"
    3  = "Running"
    4  = "Canceled"
    5  = "FinishedSuccessfully"
    6  = "FinishedWithTimeout"
    7  = "FinishedWithError"
    8  = "PipelineNotFound"
    9  = "InvalidRequiredVariable"
    10 = "SuccessfullyNotCompleted"
}

Start-Sleep -Seconds 1
$endTime = (Get-Date).AddMinutes(10)
while ($endTime -gt (Get-Date)) {
    $pipelineRun = Invoke-RestMethod -Headers $script:RequestHeaders -UseDefaultCredentials -Method Get -Uri "$ServerName/api/apc/PipelineRun/$runID" -ErrorAction Stop
    if ($null -ne $pipelineRun.EndTime) {
        Write-Host "Pipeline for file [$NetworkDrivePath] completed with state [$($pipelineRunState[$pipelineRun.State])]."
        exit 0
    }
    Write-Host "Waiting up to 10min for pipeline to finish"
    Start-Sleep 5
}
Write-Error "Pipeline [$PipelineID] did not complete within 10 minutes."
