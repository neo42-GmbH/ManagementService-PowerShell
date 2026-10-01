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
[CmdletBinding()]
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

# Get all pipelines from MMS Server.
$url = "$ServerName/api/apc/PipelineSpecificationItem?languageKey=en"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$pipelines = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials -ErrorAction Stop

if ($pipelines.Success) {
    foreach ($pipeline in $pipelines.Item) {   
        # Get all runs of the pipeline from the MMS Server.
        $url = "$ServerName/api/apc/PipelineRun/GetMany/$($pipeline.PhaseSpecificationItem.Id)"
        $runs = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials -ErrorAction Stop
        $count = 0;

        foreach ($run in ($runs | Sort-Object { Get-Date($_.StartTime) } -Descending)) {
            if ($null -ne $run.StartTime -and $null -ne $run.EndTime) {
                $count++    
                $age = New-TimeSpan -Start (Get-Date $run.EndTime) -End (Get-Date)
                if ($count -gt $MaximumRuns -or $age.Days -gt $RemoveAfterDays) {
                    # Delete the given pipeline run from the MMS Server.
                    $url = "$ServerName/api/apc/PipelineRun/$($run.RunId)"                    
                    $result = Invoke-RestMethod -Method Delete -Uri $url -Headers $headers -UseDefaultCredentials -ErrorAction Stop
                }
            }        
            elseif ($run.State -eq 4 -and $null -eq $run.EndTime) {
                # A run that is canceled while still queued (State 4 = Canceled) never gets a
                # start or end time, It has not run anything, so we delete it right away.
                $url = "$ServerName/api/apc/PipelineRun/$($run.RunId)"
                $result = Invoke-RestMethod -Method Delete -Uri $url -Headers $headers -UseDefaultCredentials -ErrorAction Stop
            }
        }
    }
}