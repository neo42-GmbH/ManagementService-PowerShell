# Empirum Cleanup API - Workflow 7: Job Status Monitor
# Monitors active jobs and displays status until completion

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerName,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [string]$JobId,

    [Parameter(Mandatory = $false)]
    [int]$RefreshInterval = 10,

    [Parameter(Mandatory = $false)]
    [switch]$StayActive
)

# Load module
Import-Module "$PSScriptRoot\neo42MmsApiModule.psm1" -Force

Write-Host "Empirum Cleanup API - Job Status Monitor" -ForegroundColor Cyan

# Configure server
Set-Neo42ServerName -ServerName $ServerName

# Status descriptions
$statusDescriptions = @{
    0 = "Unknown"
    1 = "Created"
    2 = "Queued"
    3 = "Completed"
    4 = "Running"
    5 = "Error"
    6 = "Canceled"
}

function Get-JobStatusText($job) {
    if ($null -eq $job.Status) {
        return "Status: NULL"
    }
    $status = $statusDescriptions[$job.Status]
    if (-not $status) {
        return "Status: $($job.Status) (Unknown)"
    }
    return $status
}

function Get-JobStatusColor($job) {
    if ($null -eq $job.Status) {
        return "Red"
    }
    switch ($job.Status) {
        1 { "White" }   # Created
        2 { "Yellow" }  # Queued
        3 { "Green" }   # Completed
        4 { "Yellow" }  # Running
        5 { "Red" }     # Error
        6 { "Red" }     # Canceled
        default { "Magenta" }  # Unknown status
    }
}

function Is-JobActive($job) {
    # Only jobs with status 1 (Created), 2 (Queued), 4 (Running) are truly active
    return ($job.Status -eq 1 -or $job.Status -eq 2 -or $job.Status -eq 4)
}

function Show-JobStatus($job) {
    $statusText = Get-JobStatusText $job
    $statusColor = Get-JobStatusColor $job

    Write-Host "`nJob Details:" -ForegroundColor Yellow
    Write-Host "ID: $($job.Id)" -ForegroundColor White
    Write-Host "Status: $statusText (Value: $($job.Status))" -ForegroundColor $statusColor
    Write-Host "Created: $($job.CreationTime)" -ForegroundColor Gray
    if ($job.StartTime -and $job.StartTime -ne "0001-01-01T00:00:00") {
        Write-Host "Started: $($job.StartTime)" -ForegroundColor Gray
    }
    if ($job.EndTime -and $job.EndTime -ne "0001-01-01T00:00:00") {
        Write-Host "Ended: $($job.EndTime)" -ForegroundColor Gray
    }
    Write-Host "Packages: $($job.EmpirumCleanupItems.Count)" -ForegroundColor White

    # Debug: show all available properties
    Write-Host "`nDebug - Job properties:" -ForegroundColor Cyan
    $job.PSObject.Properties | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor Gray
    }
}

try {
    if ($JobId) {
        # Monitor specific job
        Write-Host "`nMonitoring job: $JobId" -ForegroundColor Yellow

        do {
            Clear-Host
            Write-Host "Empirum Cleanup API - Job Status Monitor" -ForegroundColor Cyan
            Write-Host "Monitoring job: $JobId" -ForegroundColor Yellow
            Write-Host "Refreshing every $RefreshInterval seconds (Ctrl+C to exit)" -ForegroundColor Gray

            $job = Get-MmsApcEmpCleanupJob -JobId $JobId -TenantId $TenantId

            if ($job) {
                Show-JobStatus $job

                # Show protocol entries (last 5)
                try {
                    $protocols = Get-MmsApcEmpCleanupProtocols -JobId $JobId -CultureCode "en"
                    if ($protocols -and $protocols.Count -gt 0) {
                        Write-Host "`nLatest protocol entries:" -ForegroundColor Yellow
                        $protocols | Sort-Object Time -Descending | Select-Object -First 5 | ForEach-Object {
                            $time = [DateTime]::Parse($_.Time).ToString("HH:mm:ss")
                            $level = switch ($_.LogLevel) {
                                0 { "INFO" }
                                1 { "WARN" }
                                2 { "ERROR" }
                                default { "LOG$($_.LogLevel)" }
                            }
                            Write-Host "$time [$level] $($_.ResourceMessage)" -ForegroundColor Gray
                        }
                    }
                } catch {
                    Write-Host "`nProtocol entries not available" -ForegroundColor Gray
                }

                if ($job.Status -eq 3) {
                    Write-Host "`nJob completed successfully!" -ForegroundColor Green
                    break
                } elseif ($job.Status -eq 5 -or $job.Status -eq 6) {
                    $statusText = Get-JobStatusText $job
                    Write-Host "`nJob ended with status: $statusText" -ForegroundColor Red
                    break
                }

            } else {
                Write-Error "Job $JobId not found"
                break
            }

            Start-Sleep -Seconds $RefreshInterval

        } while ($true)

    } else {
        # Show all jobs (with Stay Active mode)
        if ($StayActive) {
            Write-Host "`nStay Active mode - Continuously monitoring for new jobs..." -ForegroundColor Cyan
            Write-Host "Refreshing every $RefreshInterval seconds (Ctrl+C to exit)" -ForegroundColor Gray

            $lastJobCount = 0
            $lastActiveJobs = @()

            do {
                try {
                    $allJobs = Get-MmsApcEmpCleanupJob -TenantId $TenantId -All
                    $activeJobs = @()

                    if ($allJobs) {
                        $activeJobs = $allJobs | Where-Object { Is-JobActive $_ }
                    }

                    # Check for changes
                    $currentTime = Get-Date -Format "HH:mm:ss"
                    $hasChanges = $false

                    if ($allJobs.Count -ne $lastJobCount) {
                        $hasChanges = $true
                        $lastJobCount = $allJobs.Count
                    }

                    # New or changed active jobs
                    $newActiveJobs = @()
                    if ($activeJobs) {
                        foreach ($activeJob in $activeJobs) {
                            $existing = $lastActiveJobs | Where-Object { $_.Id -eq $activeJob.Id -and $_.Status -eq $activeJob.Status }
                            if (-not $existing) {
                                $newActiveJobs += $activeJob
                                $hasChanges = $true
                            }
                        }
                    }

                    # Completed jobs
                    $completedJobs = @()
                    if ($lastActiveJobs) {
                        foreach ($lastJob in $lastActiveJobs) {
                            $stillActive = $activeJobs | Where-Object { $_.Id -eq $lastJob.Id }
                            if (-not $stillActive) {
                                # Job is no longer active - check status
                                $currentJob = $allJobs | Where-Object { $_.Id -eq $lastJob.Id }
                                if ($currentJob) {
                                    $completedJobs += $currentJob
                                    $hasChanges = $true
                                }
                            }
                        }
                    }

                    if ($hasChanges) {
                        Clear-Host
                        Write-Host "Empirum Cleanup API - Job Status Monitor (Stay Active)" -ForegroundColor Cyan
                        Write-Host "[$currentTime] Status update for tenant $TenantId" -ForegroundColor Yellow
                        Write-Host "Refreshing every $RefreshInterval seconds (Ctrl+C to exit)" -ForegroundColor Gray

                        # Show new jobs
                        if ($newActiveJobs.Count -gt 0) {
                            Write-Host "`n=== NEW/CHANGED ACTIVE JOBS ===" -ForegroundColor Green
                            foreach ($newJob in $newActiveJobs) {
                                $statusText = Get-JobStatusText $newJob
                                Write-Host "NEW JOB: $($newJob.Id) - $statusText (Status: $($newJob.Status)) - $($newJob.CreationTime)" -ForegroundColor Green
                            }
                        }

                        # Show completed jobs
                        if ($completedJobs.Count -gt 0) {
                            Write-Host "`n=== COMPLETED JOBS ===" -ForegroundColor Yellow
                            foreach ($completedJob in $completedJobs) {
                                $statusText = Get-JobStatusText $completedJob
                                $color = Get-JobStatusColor $completedJob
                                Write-Host "ENDED: $($completedJob.Id) - $statusText (Status: $($completedJob.Status)) - $($completedJob.EndTime)" -ForegroundColor $color
                            }
                        }

                        # Currently active jobs
                        if ($activeJobs.Count -gt 0) {
                            Write-Host "`n=== CURRENTLY ACTIVE JOBS ===" -ForegroundColor Cyan
                            foreach ($activeJob in $activeJobs) {
                                $statusText = Get-JobStatusText $activeJob
                                $color = Get-JobStatusColor $activeJob
                                Write-Host "$($activeJob.Id) - $statusText (Status: $($activeJob.Status)) - $($activeJob.CreationTime) - $($activeJob.EmpirumCleanupItems.Count) packages" -ForegroundColor $color
                            }
                        } else {
                            Write-Host "`n=== STATUS ===" -ForegroundColor White
                            Write-Host "No active jobs - Waiting for new jobs..." -ForegroundColor Gray
                        }

                        Write-Host "`nTotal job count: $($allJobs.Count) | Active jobs: $($activeJobs.Count)" -ForegroundColor Gray
                    }

                    $lastActiveJobs = $activeJobs

                } catch {
                    Write-Host "[$currentTime] Error retrieving jobs: $($_.Exception.Message)" -ForegroundColor Red
                }

                Start-Sleep -Seconds $RefreshInterval

            } while ($true)

        } else {
            # One-time display of all jobs
            Write-Host "`nRetrieving all jobs for tenant..." -ForegroundColor Yellow

            $allJobs = Get-MmsApcEmpCleanupJob -TenantId $TenantId -All

            if (-not $allJobs -or $allJobs.Count -eq 0) {
                Write-Host "No jobs found for this tenant." -ForegroundColor Yellow
                return
            }

            Write-Host "`nAll jobs for tenant $TenantId" -ForegroundColor White

            foreach ($job in $allJobs | Sort-Object CreationTime -Descending) {
                $statusText = Get-JobStatusText $job
                $color = Get-JobStatusColor $job

                Write-Host "$($job.Id) - $statusText (Status: $($job.Status)) - $($job.CreationTime) - $($job.EmpirumCleanupItems.Count) packages" -ForegroundColor $color
            }

            # Highlight active jobs
            $activeJobs = $allJobs | Where-Object { Is-JobActive $_ }
            if ($activeJobs) {
                Write-Host "`nActive jobs found:" -ForegroundColor Yellow
                foreach ($activeJob in $activeJobs) {
                    $statusText = Get-JobStatusText $activeJob
                    Write-Host "- $($activeJob.Id) ($statusText - Status: $($activeJob.Status))" -ForegroundColor Cyan
                }

                Write-Host "`nTip: Use the -JobId parameter to monitor a specific job" -ForegroundColor Gray
                Write-Host "Or use -StayActive to continuously wait for new jobs" -ForegroundColor Gray
            } else {
                Write-Host "`nNo active jobs found." -ForegroundColor Green
                Write-Host "Use -StayActive to wait for new jobs" -ForegroundColor Gray
            }
        }
    }

} catch {
    Write-Error "Error during job monitoring: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nJob monitoring ended." -ForegroundColor Green
