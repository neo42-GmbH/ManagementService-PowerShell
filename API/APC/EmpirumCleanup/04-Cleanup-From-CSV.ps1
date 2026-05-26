# Empirum Cleanup API - Workflow 4: Cleanup based on CSV list
# Starts a cleanup job for packages from a previously exported CSV file

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerName,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("NoAssignmentInstallApproved", "NoAssignmentNoInstallApproved", "AllPackages")]
    [string]$CleanupAction,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$SkipDuplicateCheck
)

# Load module
Import-Module "$PSScriptRoot\neo42MmsApiModule.psm1" -Force

Write-Host "Empirum Cleanup API - Cleanup from CSV list" -ForegroundColor Cyan


# Validate inputs
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}

# Configure server
Set-Neo42ServerName -ServerName $ServerName

Write-Host "`nLoading CSV file..." -ForegroundColor Yellow
Write-Host "File: $CsvPath" -ForegroundColor Gray

try {
    # Load CSV (supports legacy German and current English column names)
    $csvData = Import-Csv -Path $CsvPath -Delimiter ';' -Encoding UTF8

    if (-not $csvData -or $csvData.Count -eq 0) {
        Write-Error "CSV file is empty or could not be read."
        exit 1
    }

    Write-Host "CSV loaded: $($csvData.Count) entries" -ForegroundColor Green

    # Map CSV columns to API field names (supports legacy German column names)
    $cleanupItems = @()
    foreach ($row in $csvData) {
        $item = @{
            SoftwareId = if ($row.SoftwareId) { $row.SoftwareId } else { $row.SoftwareName + "_" + $row.Version }
            SoftwareName = if ($row.SoftwareName) { $row.SoftwareName } else { "" }
            SoftwareDev = if ($row.Manufacturer) { $row.Manufacturer } elseif ($row.Hersteller) { $row.Hersteller } elseif ($row.SoftwareDev) { $row.SoftwareDev } else { "" }
            SoftwareProd = if ($row.Product) { $row.Product } elseif ($row.Produkt) { $row.Produkt } elseif ($row.SoftwareProd) { $row.SoftwareProd } else { "" }
            Version = if ($row.Version) { $row.Version } else { "" }
            Directory = if ($row.Directory) { $row.Directory } elseif ($row.Verzeichnis) { $row.Verzeichnis } else { "" }
            DirSize = if ($row.Size) { $row.Size } elseif ($row.Groesse) { $row.Groesse } elseif ($row.DirSize) { $row.DirSize } else { "0" }
            PackageName = if ($row.PackageName) { $row.PackageName } else { "" }
            InvInstalations = if ($row.Installations) { $row.Installations } elseif ($row.Installationen) { $row.Installationen } elseif ($row.InvInstalations) { $row.InvInstalations } else { 0 }
            Status = if ($row.Status) { $row.Status } else { 0 }
        }
        $cleanupItems += $item
    }

    Write-Host "`nPreparing cleanup job..." -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "DRY RUN MODE - No actual cleanup!" -ForegroundColor Red
        Write-Host "The following packages would be cleaned up:" -ForegroundColor Yellow
        foreach ($item in $cleanupItems) {
            Write-Host "- $($item.SoftwareName) ($($item.Version)) - $($item.DirSize)" -ForegroundColor White
        }
        Write-Host "`nTotal count: $($cleanupItems.Count) packages" -ForegroundColor Cyan
        return
    }

    # Create cleanup job
    $jobId = New-MmsApcEmpCleanupJob -TenantId $TenantId -CleanupAction $CleanupAction

    if (-not $jobId) {
        Write-Error "Error creating cleanup job"
        exit 1
    }

    Write-Host "Cleanup job created: $jobId" -ForegroundColor Green

    # Check for duplicates (if desired)
    $duplicatesFound = $false
    if (-not $SkipDuplicateCheck) {
        Write-Host "`nChecking for duplicates..." -ForegroundColor Yellow
        $duplicates = Test-MmsApcEmpCleanupDuplicates -TenantId $TenantId -EmpirumCleanupItems $cleanupItems -JobId $jobId

        if ($duplicates -and $duplicates.Count -gt 0) {
            $duplicatesFound = $true
            Write-Warning "Duplicates found: $($duplicates.Count) items"
            Write-Host "Duplicates will still be included in the job." -ForegroundColor Yellow
        } else {
            Write-Host "No duplicates found." -ForegroundColor Green
        }
    }

    # Start cleanup job
    Write-Host "`nStarting cleanup job..." -ForegroundColor Yellow
    $startResult = Start-MmsApcEmpCleanupJob -JobId $jobId -EmpirumCleanupItems $cleanupItems -DuplicatesFound $duplicatesFound

    if ($startResult -and $startResult.Success) {
        Write-Host "`nCleanup job started successfully!" -ForegroundColor Green
        Write-Host "Job ID: $jobId" -ForegroundColor White
        Write-Host "Packages: $($cleanupItems.Count)" -ForegroundColor White
        Write-Host "Duplicates: $(if ($duplicatesFound) { 'Yes' } else { 'No' })" -ForegroundColor White

        Write-Host "`nThe job is now running in the background." -ForegroundColor Cyan
        Write-Host "Use Workflow 7 (Job Status Monitor) to track progress." -ForegroundColor Yellow

    } else {
        Write-Error "Error starting cleanup job"
        exit 1
    }

} catch {
    Write-Error "Cleanup error: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nCleanup workflow completed." -ForegroundColor Green
