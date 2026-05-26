# Empirum Cleanup Scripts

A small set of scripts to find and clean up unused Empirum packages.

## Before you start

- Open PowerShell on a machine that can reach your Empirum / neo42 Management Service server (MMS).
- Change into this folder, for example: `cd C:\EmpirumCleanup`
- Have ready: the **server name and port** of the Management Service. You can find this in the Server Configurator of the MMS server

## Step 1 - Find your Tenant ID

- Run: `.\01-List-Tenants.ps1 -ServerName "YourServer"`
- All tenants are listed on screen.
- Write down the **Tenant ID** of the tenant you want to clean up. You will need it for every following step.

## Step 2 - Get an overview (export to Excel)

Choose one or both exports. Each produces a CSV that you can open in Excel.

- Packages **without assignment but with install approval** (review carefully before deleting):
  - `.\02-Export-NoAssignmentInstallApproved.ps1 -ServerName "YourServer" -TenantId "YourTenantId" -OutputPath "C:\Temp"`
- Packages **without assignment and without install approval** (the safest cleanup candidates):
  - `.\03-Export-NoAssignmentNoInstallApproved.ps1 -ServerName "YourServer" -TenantId "YourTenantId" -OutputPath "C:\Temp"`
- Open the resulting CSV in Excel, review the list, and delete any rows you want to **keep**.
- Save the file.

## Step 3 - Clean up

You have three ways to start a cleanup. Pick the one that fits your situation.

### Option A - Clean up from the edited CSV (recommended)

- Run:
  - `.\04-Cleanup-From-CSV.ps1 -ServerName "YourServer" -TenantId "YourTenantId" -CsvPath "C:\Temp\NoAssignmentNoInstallApproved.csv" -CleanupAction NoAssignmentNoInstallApproved`
- Use `-CleanupAction NoAssignmentInstallApproved` instead if you are cleaning up the other category.
- Add `-DryRun` at the end first to preview without changing anything.

### Option B - Quick cleanup by name filter (no install approval)

- Best starting point - these packages are unused.
- Run:
  - `.\06-Cleanup-Filter-NoInstallApproved.ps1 -ServerName "YourServer" -TenantId "YourTenantId" -FilterText "Adobe"`
- Replace `"Adobe"` with any text contained in the software name.
- You will be asked to confirm before anything happens.
- Add `-DryRun` to preview first.

### Option C - Quick cleanup by name filter (install approved)

- Use with care - these packages still have an install approval.
- Run:
  - `.\05-Cleanup-Filter-InstallApproved.ps1 -ServerName "YourServer" -TenantId "YourTenantId" -FilterText "Adobe"`
- Add `-DryRun` to preview first.

## Step 4 - Watch the progress

- After starting a cleanup you will see a **Job ID** in the output. Write it down.
- Show all jobs for the tenant:
  - `.\07-Job-Status-Monitor.ps1 -ServerName "YourServer" -TenantId "YourTenantId"`
- Watch one specific job until it finishes:
  - `.\07-Job-Status-Monitor.ps1 -ServerName "YourServer" -TenantId "YourTenantId" -JobId "YourJobId"`
- Stay open and wait for new jobs:
  - `.\07-Job-Status-Monitor.ps1 -ServerName "YourServer" -TenantId "YourTenantId" -StayActive`
- Press `Ctrl + C` to leave the monitor.

## Tips

- Always run with `-DryRun` first if you are unsure.
- Start with the **NoAssignmentNoInstallApproved** category - it is the safest.
- Keep the exported CSV files as a record of what was cleaned up.
