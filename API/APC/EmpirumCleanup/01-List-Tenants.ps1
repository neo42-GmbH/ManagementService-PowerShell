# Empirum Cleanup API - Workflow 1: List tenants
# Displays all available tenants and pauses for notes

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerName
)

# Load module
# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Write-Host "Empirum Cleanup API - Tenant List" -ForegroundColor Cyan


# Open the session that every following call uses
Connect-MmsApi -ServerName $ServerName

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
