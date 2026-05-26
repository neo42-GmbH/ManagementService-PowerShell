# Empirum Cleanup API - Workflow 2: Export NoAssignmentInstallApproved CSV
# Exports all packages without assignment but with install approval to CSV

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerName,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [System.IO.DirectoryInfo]$OutputPath
)

$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "NoAssignmentInstallApproved.csv"

# Load module
Import-Module "$PSScriptRoot\neo42MmsApiModule.psm1" -Force

Write-Host "Empirum Cleanup API - Export NoAssignmentInstallApproved" -ForegroundColor Cyan


# Configure server
Set-Neo42ServerName -ServerName $ServerName

# Retrieve package list
Write-Host "`nRetrieving package list (NoAssignmentInstallApproved)..." -ForegroundColor Yellow
Write-Host "Tenant ID: $TenantId" -ForegroundColor Gray

try {
    $packages = Get-MmsApcEmpCleanupPackageList -Action NoAssignmentInstallApproved -TenantId $TenantId

    if ($packages -and $packages.Count -gt 0) {
        Write-Host "Found: $($packages.Count) packages" -ForegroundColor Green

        # Export to CSV
        $csvData = $packages | Select-Object @(
            @{Name='SoftwareName'; Expression={$_.SoftwareName}},
            @{Name='Manufacturer'; Expression={$_.SoftwareDev}},
            @{Name='Product'; Expression={$_.SoftwareProd}},
            @{Name='Version'; Expression={$_.Version}},
            @{Name='PackageName'; Expression={$_.PackageName}},
            @{Name='Directory'; Expression={$_.Directory}},
            @{Name='Size'; Expression={$_.DirSize}},
            @{Name='Installations'; Expression={$_.InvInstalations}},
            @{Name='Status'; Expression={$_.Status}},
            @{Name='SoftwareId'; Expression={$_.SoftwareId}}
        )

        $csvData | Export-Csv -Path $filePath -NoTypeInformation -Delimiter ';' -Encoding UTF8

        Write-Host "`nExport successful!" -ForegroundColor Green
        Write-Host "File: $filePath" -ForegroundColor White
        Write-Host "Number of packages: $($csvData.Count)" -ForegroundColor White

        # Show statistics
        $totalSize = 0
        $packagesWithSize = $packages | Where-Object { $_.DirSize -and $_.DirSize -ne "0" -and $_.DirSize -ne "" }
        foreach ($pkg in $packagesWithSize) {
            # Try to parse size (various formats possible)
            $sizeString = $pkg.DirSize -replace '[^0-9.]', ''
            if ($sizeString -and [double]::TryParse($sizeString, [ref]$null)) {
                $totalSize += [double]$sizeString
            }
        }

        if ($totalSize -gt 0) {
            $totalSizeGB = [Math]::Round($totalSize / 1GB, 2)
            Write-Host "Estimated total size: $totalSizeGB GB" -ForegroundColor Cyan
        }

        # Show top 10 largest packages
        $topPackages = $packages | Where-Object { $_.DirSize -and $_.DirSize -ne "0" } |
                      Sort-Object { [double]($_.DirSize -replace '[^0-9.]', '') } -Descending |
                      Select-Object -First 10

        if ($topPackages) {
            Write-Host "`nTop 10 largest packages:" -ForegroundColor Yellow
            Write-Host "-" * 60 -ForegroundColor Gray
            foreach ($pkg in $topPackages) {
                Write-Host "$($pkg.SoftwareName) ($($pkg.Version)) - $($pkg.DirSize)" -ForegroundColor White
            }
        }

    } else {
        Write-Warning "No packages found for NoAssignmentInstallApproved."
    }

} catch {
    Write-Error "Export error: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nExport completed. The CSV file can be opened in Excel." -ForegroundColor Green
Write-Host "Note: This list can be used for selective cleanup operations." -ForegroundColor Yellow
