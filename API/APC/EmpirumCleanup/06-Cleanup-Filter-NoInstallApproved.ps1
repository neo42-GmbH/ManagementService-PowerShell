# Empirum Cleanup API - Workflow 6: Cleanup with filter NoAssignmentNoInstallApproved
# Starts cleanup for filtered packages without assignment and without install approval

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerName,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$FilterText,

    [Parameter(Mandatory = $false)]
    [ValidateSet("SoftwareName", "SoftwareDev", "PackageName", "Version")]
    [string]$FilterField = "SoftwareName",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$ExactMatch
)

# Load module
Import-Module "$PSScriptRoot\neo42MmsApiModule.psm1" -Force

Write-Host "Empirum Cleanup API - Filter Cleanup (NoInstallApproved)" -ForegroundColor Cyan


# Configure server
Set-Neo42ServerName -ServerName $ServerName

# Retrieve package list
Write-Host "`nRetrieving package list (NoAssignmentNoInstallApproved)..." -ForegroundColor Yellow
Write-Host "Tenant ID: $TenantId" -ForegroundColor Gray
Write-Host "Filter: $FilterText (Field: $FilterField)" -ForegroundColor Gray
Write-Host "Exact match: $(if ($ExactMatch) { 'Yes' } else { 'No (substring)' })" -ForegroundColor Gray

try {
    $allPackages = Get-MmsApcEmpCleanupPackageList -Action NoAssignmentNoInstallApproved -TenantId $TenantId

    if (-not $allPackages -or $allPackages.Count -eq 0) {
        Write-Host "No packages found for NoAssignmentNoInstallApproved." -ForegroundColor Green
        Write-Host "That is good - all packages either have assignments or install approvals." -ForegroundColor Green
        return
    }

    Write-Host "Found: $($allPackages.Count) packages total" -ForegroundColor White

    # Filter packages
    Write-Host "`nApplying filter..." -ForegroundColor Yellow

    if ($ExactMatch) {
        $filteredPackages = $allPackages | Where-Object { $_.$FilterField -eq $FilterText }
    } else {
        $filteredPackages = $allPackages | Where-Object { $_.$FilterField -like "*$FilterText*" }
    }

    if (-not $filteredPackages -or $filteredPackages.Count -eq 0) {
        Write-Warning "No packages found with filter '$FilterText' in field '$FilterField'"
        Write-Host "`nAvailable values for $FilterField (first 20):" -ForegroundColor Yellow
        $allPackages | Select-Object -First 20 | ForEach-Object {
            Write-Host "- $($_.$FilterField)" -ForegroundColor Gray
        }
        return
    }

    Write-Host "After filter: $($filteredPackages.Count) packages" -ForegroundColor Green

    # Show filtered packages
    Write-Host "`nFiltered packages:" -ForegroundColor Yellow
    Write-Host "-" * 80 -ForegroundColor Gray
    $totalSize = 0
    foreach ($pkg in $filteredPackages) {
        Write-Host "$($pkg.SoftwareName) ($($pkg.Version)) - $($pkg.SoftwareDev) - $($pkg.DirSize)" -ForegroundColor White

        # Sum size
        if ($pkg.DirSize -and $pkg.DirSize -ne "0" -and $pkg.DirSize -ne "") {
            $sizeString = $pkg.DirSize -replace '[^0-9.]', ''
            if ($sizeString -and [double]::TryParse($sizeString, [ref]$null)) {
                $totalSize += [double]$sizeString
            }
        }
    }

    if ($totalSize -gt 0) {
        $totalSizeGB = [Math]::Round($totalSize / 1GB, 2)
        Write-Host "`nEstimated total size: $totalSizeGB GB" -ForegroundColor Cyan
    }

    if ($DryRun) {
        Write-Host "`nDRY RUN MODE - No actual cleanup!" -ForegroundColor Red
        Write-Host "$($filteredPackages.Count) packages would be cleaned up." -ForegroundColor Yellow
        return
    }

    # Information
    Write-Host "`nINFO: These packages are the best cleanup candidates!" -ForegroundColor Green
    Write-Host "They have neither assignments nor install approvals." -ForegroundColor Green

    # Confirm
    $confirm = Read-Host "`nDo you want to continue with the cleanup? (yes/no)"

    if ($confirm -ne "yes" -and $confirm -ne "y" -and $confirm -ne "ja" -and $confirm -ne "j") {
        Write-Host "Cleanup canceled." -ForegroundColor Yellow
        return
    }

    # Create cleanup job
    Write-Host "`nCreating cleanup job..." -ForegroundColor Yellow
    $jobId = New-MmsApcEmpCleanupJob -TenantId $TenantId -CleanupAction NoAssignmentNoInstallApproved

    if (-not $jobId) {
        Write-Error "Error creating cleanup job"
        exit 1
    }

    Write-Host "Cleanup job created: $jobId" -ForegroundColor Green

    # Check for duplicates
    Write-Host "`nChecking for duplicates..." -ForegroundColor Yellow
    $duplicates = Test-MmsApcEmpCleanupDuplicates -TenantId $TenantId -EmpirumCleanupItems $filteredPackages -JobId $jobId
    $duplicatesFound = $duplicates -and $duplicates.Count -gt 0

    if ($duplicatesFound) {
        Write-Warning "Duplicates found: $($duplicates.Count) items"
    } else {
        Write-Host "No duplicates found." -ForegroundColor Green
    }

    # Start cleanup job
    Write-Host "`nStarting cleanup job..." -ForegroundColor Yellow
    $startResult = Start-MmsApcEmpCleanupJob -JobId $jobId -EmpirumCleanupItems $filteredPackages -DuplicatesFound $duplicatesFound

    if ($startResult -and $startResult.Success) {
        Write-Host "`nCleanup job started successfully!" -ForegroundColor Green
        Write-Host "Job ID: $jobId" -ForegroundColor White
        Write-Host "Filter: $FilterText ($FilterField)" -ForegroundColor White
        Write-Host "Packages: $($filteredPackages.Count)" -ForegroundColor White
        Write-Host "Duplicates: $(if ($duplicatesFound) { 'Yes' } else { 'No' })" -ForegroundColor White

        Write-Host "`nThe job is now running in the background." -ForegroundColor Cyan
        Write-Host "Use Workflow 7 to track progress." -ForegroundColor Yellow

    } else {
        Write-Error "Error starting cleanup job"
        exit 1
    }

} catch {
    Write-Error "Cleanup error: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nFilter cleanup completed." -ForegroundColor Green
