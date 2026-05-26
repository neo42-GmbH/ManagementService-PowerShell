# Empirum Cleanup API - Workflow 1: List tenants
# Displays all available tenants and pauses for notes

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerName
)

# Load module
Import-Module "$PSScriptRoot\neo42MmsApiModule.psm1" -Force

Write-Host "Empirum Cleanup API - Tenant List" -ForegroundColor Cyan


# Configure server
Set-Neo42ServerName -ServerName $ServerName

# Retrieve all tenants
Write-Host "`nRetrieving all tenants..." -ForegroundColor Yellow

try {
    $tenants = Get-MmsApcEmpCleanupTenant -All

    if ($tenants) {
        Write-Host "`nAvailable tenants:" -ForegroundColor Green


        $counter = 1
        foreach ($tenant in $tenants) {
            Write-Host "$counter. Tenant Name: $($tenant.TenantName)" -ForegroundColor White
            Write-Host "   Tenant ID:   $($tenant.TenantId)" -ForegroundColor Cyan
            if ($tenant.Description) {
                Write-Host "   Description: $($tenant.Description)" -ForegroundColor Gray
            }
            Write-Host ""
            $counter++
        }


        Write-Host "NOTE: Make a note of the Tenant ID for the other workflows!" -ForegroundColor Yellow
        Write-Host "The Tenant ID is required for all other cleanup operations." -ForegroundColor Yellow

    } else {
        Write-Warning "No tenants found or an API error occurred."
    }

} catch {
    Write-Error "Error retrieving tenants: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nPress any key to continue..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
