<#
.SYNOPSIS
    Detects version-related issues in Workspace ONE (WSO) internal application packages.

.DESCRIPTION
    This script connects to a Workspace ONE UEM tenant via the REST API and analyzes all
    internal applications to identify packages where the deployed version is out of sync
    with the expected neo42 reference catalog or has anomalous version numbering.

    Findings are printed as a table showing BaseName, top neo42/original versions,
    the expected packages version, and the reason(s) the entry was flagged.

.PARAMETER ApiUrl
    Prompted at runtime. Base URL of the Workspace ONE UEM REST API
    (e.g. https://as1234.awmdm.com/api).

.PARAMETER UserName
    Prompted at runtime. Username of an account with read access to internal applications.

.PARAMETER Password
    Prompted at runtime as a SecureString. Password for the supplied user account.

.PARAMETER ApiKey
    Prompted at runtime as a SecureString. Tenant API key sent via the aw-tenant-code header.

.INPUTS
    None. All inputs are gathered interactively via Read-Host.

.OUTPUTS
    Two formatted tables to the console:
      - All processed applications with their derived BaseName, OriginalVersion, and Neo42Version.
      - All flagged applications requiring action, with the reason for the alert.

.NOTES
    Author   : neo42 GmbH
    Requires : PowerShell 5.1 or later
               Network access to the configured Workspace ONE UEM tenant
               Workspace ONE UEM account with permission to query internal apps
#>

# WorkspaceOne Internal Apps - PowerShell Script
$ApiUrl = Read-Host "Enter the API URL for your WSO Tenant"
$UserName = Read-Host "Enter the username"
$PasswordSecure = Read-Host "Enter the password" -AsSecureString
$ApiKeySecure = Read-Host "Enter the API key" -AsSecureString

$Password = [System.Net.NetworkCredential]::new("", $PasswordSecure).Password
$ApiKey = [System.Net.NetworkCredential]::new("", $ApiKeySecure).Password

  $packages = @(
      [PSCustomObject]@{ Name = "Microsoft Windows 10 ESU - Patching";    Version = "1.0" }
      [PSCustomObject]@{ Name = "Oleksandr Reminnyi StepsToReproduce";    Version = "1.0.0.1439" }
      [PSCustomObject]@{ Name = "Juergen Riegel FreeCAD";                 Version = "1.1.1" }
      [PSCustomObject]@{ Name = "Proton Proton Authenticator";            Version = "1.1.4" }
      [PSCustomObject]@{ Name = "XnView XnViewMP";                        Version = "1.10.5" }
      [PSCustomObject]@{ Name = "XnView XnConvert";                       Version = "1.106.0" }
      [PSCustomObject]@{ Name = "XnView XnResize";                        Version = "1.11" }
      [PSCustomObject]@{ Name = "Microsoft Visual Studio Code x64";       Version = "1.117.0" }
      [PSCustomObject]@{ Name = "Citrix VDA Cleanup Utility";             Version = "1.12.0.37" }
      [PSCustomObject]@{ Name = "Karakun OpenWebStart";                   Version = "1.13.0" }
      [PSCustomObject]@{ Name = "Freeplane Team Freeplane";               Version = "1.13.2" }
      [PSCustomObject]@{ Name = "TortoiseSVN TortoiseSVN";                Version = "1.14.9" }
      [PSCustomObject]@{ Name = "Skymatic Cryptomator";                   Version = "1.19.2.6322" }
      [PSCustomObject]@{ Name = "Microsoft Remotedesktop";                Version = "1.2.7099.0" }
      [PSCustomObject]@{ Name = "Microsoft Outlook for Windows";          Version = "1.2025.604.100" }
      [PSCustomObject]@{ Name = "Red Hat Podman Desktop";                 Version = "1.26.2" }
      [PSCustomObject]@{ Name = "AM Crypto VeraCrypt";                    Version = "1.26.24" }
      [PSCustomObject]@{ Name = "Ultramarinviewer Ultramarinviewer";      Version = "1.3.0.0" }
      [PSCustomObject]@{ Name = "Greenshot.org Greenshot";                Version = "1.3.315" }
      [PSCustomObject]@{ Name = "voidtools Everything";                   Version = "1.4.1.1032" }
      [PSCustomObject]@{ Name = "Inkscape.org Inkscape";                  Version = "1.4.3" }
      [PSCustomObject]@{ Name = "Quba Quba";                              Version = "1.5.0.0" }
      [PSCustomObject]@{ Name = "Ultravnc.org UltraVNC Server";           Version = "1.6.4.0" }
      [PSCustomObject]@{ Name = "Ultravnc.org UltraVNC Viewer";           Version = "1.6.4.0" }
      [PSCustomObject]@{ Name = "Ultravnc.org UltraVNC Server + Viewer";  Version = "1.6.4.0" }
      [PSCustomObject]@{ Name = "Scribus.net Scribus";                    Version = "1.6.6" }
      [PSCustomObject]@{ Name = "Microsoft Teams";                        Version = "1.7.0.13456" }
      [PSCustomObject]@{ Name = "Jamie OConnell Desktop Restore";         Version = "1.7.2.083" }
      [PSCustomObject]@{ Name = "Next Generation Software mRemoteNG";     Version = "1.76.20.24615" }
      [PSCustomObject]@{ Name = "Microsoft Visual Studio Code";           Version = "1.83.1" }
      [PSCustomObject]@{ Name = "ProjectLibre.org ProjectLibre";          Version = "1.9.8" }
      [PSCustomObject]@{ Name = "Tailscale Tailscale";                    Version = "1.96.3" }
  )

  # --- Auth Headers ---
  $basicToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${UserName}:${Password}"))
  $headers = @{
      "Authorization"  = "Basic $basicToken"
      "aw-tenant-code" = $ApiKey
      "Accept"         = "application/json"
  }

  # --- Phase 1: Alle App-IDs via paginierter Suche holen ---
  $page            = 0
  $pageSize        = 500
  $allSearchedApps = [System.Collections.Generic.List[object]]::new()

  Write-Host "Phase 1: Suche alle internen Apps..."

  do {
      $searchUri = "$ApiUrl/mam/apps/search?type=App&applicationtype=Internal&page=$page&pagesize=$pageSize"
      $response  = Invoke-RestMethod -Uri $searchUri -Method GET -Headers $headers

      $total = $response.Total
      $batch = $response.Application
      if ($batch) { $allSearchedApps.AddRange($batch) }

      Write-Host "  Seite $page geladen - $($allSearchedApps.Count) / $total Apps"
      $page++
  } while ($allSearchedApps.Count -lt $total)

  if ($allSearchedApps.Count -eq 0) {
    Write-Host "Es wurden keine Apps gefunden. ConnectionTest fehlgeschlagen." -ForegroundColor Red
    break
}

  Write-Host "Phase 1 abgeschlossen: $($allSearchedApps.Count) Apps gefunden.`n"

  # --- Phase 2: BaseName ermitteln und neo42-Version vergeben ---
  Write-Host "Phase 2: Verarbeite App-Namen und vergebe neo42-Versionen..."

  function Get-BaseName {
      param([string]$appName, [string]$fileVersion)
      $parts = $fileVersion -split '\.'
      for ($j = $parts.Count; $j -ge 1; $j--) {
          $prefix = ($parts[0..($j - 1)]) -join '.'
          if ($prefix.Length -gt 0 -and $appName.Contains($prefix)) {
              $cleaned = $appName.Replace($prefix, '').Trim()
              # Übrig gebliebene Versions-Fragmente entfernen: " .142", ".5861" etc.
              $cleaned = $cleaned -replace '\s*\.\d+(\.\d+)*$', ''
              $cleaned = $cleaned -replace '^\.\d+(\.\d+)*\s*', ''
              return ($cleaned.Trim() -replace '\s+', ' ')
          }
      }
      return $appName.Trim()
  }

  function ConvertTo-SortableVersion {
      param([string]$v)
      try { return [System.Version]::Parse($v) }
      catch { return [System.Version]::new(0, 0) }
  }
  $results = $allSearchedApps |
      ForEach-Object {
          [PSCustomObject]@{
              ApplicationName   = $_.ApplicationName
              ActualFileVersion = $_.ActualFileVersion
              BaseName          = Get-BaseName $_.ApplicationName $_.ActualFileVersion
              AppVersion = $_.AppVersion
          }
      } |
      Group-Object -Property BaseName |
      ForEach-Object {
          $sorted = $_.Group | Sort-Object { ConvertTo-SortableVersion $_.ActualFileVersion }
          $minor  = 0
          foreach ($app in $sorted) {
              [PSCustomObject]@{
                  BaseName        = $app.BaseName
                  OriginalName    = $app.ApplicationName
                  OriginalVersion = $app.ActualFileVersion
                  AppVersion = $app.AppVersion
                  Neo42Version    = "1.$minor.0"
              }
              $minor++
          }
      }

  Write-Host "Phase 2 abgeschlossen: $($results.Count) Einträge verarbeitet.`n"

  $results | Format-Table BaseName, OriginalVersion, Neo42Version -AutoSize

  # --- Phase 3: Vergleich gegen $packages ---
  Write-Host "Phase 3: Prüfe gegen Packages-Liste..."
      function ConvertTo-SortableVersion {
      param([string]$v)
      try { return [System.Version]::Parse($v) }
      catch { return [System.Version]::new(0, 0) }
  }

  # Pro BaseName den höchsten Neo42- und Original-Eintrag ermitteln
  $grouped = $results |
      Group-Object -Property BaseName |
      ForEach-Object {
          $sorted = $_.Group | Sort-Object { ConvertTo-SortableVersion $_.Neo42Version }
          $top    = $sorted | Select-Object -Last 1
          $minAppVer = ($_.Group | Sort-Object { ConvertTo-SortableVersion $_.AppVersion } | Select-Object -First 1).AppVersion
          [PSCustomObject]@{
              BaseName        = $_.Name
              TopNeo42Version = $top.Neo42Version
              TopOrigVersion  = $top.OriginalVersion
              TopAppVersion   = $top.AppVersion
              MinAppVersion   = $minAppVer
          }
      }

  # Prüfbedingungen anwenden
  $alerts = foreach ($group in $grouped) {
      $pkg         = $packages | Where-Object { $_.Name -eq $group.BaseName }
      $reasons     = [System.Collections.Generic.List[string]]::new()

      # Bedingung 1: Name in $packages gefunden und Neo42Version > packages Version
      if ($pkg) {
          $neo42  = ConvertTo-SortableVersion $group.TopNeo42Version
          $pkgVer = ConvertTo-SortableVersion $pkg.Version
          if ($neo42 -ge $pkgVer) {
              $reasons.Add("Neo42 ($($group.TopNeo42Version)) >= Packages ($($pkg.Version))")
          }
      }

      # Bedingung 2: höchste OriginalVersion hat Major < 1 (z.B. 0.83)
      if ((ConvertTo-SortableVersion $group.TopOrigVersion).Major -lt 1 -and
      (ConvertTo-SortableVersion $group.TopAppVersion).Major -ge 1) {
        $reasons.Add("OriginalVersion < 1 ($($group.TopOrigVersion))")
      }

      if ($reasons.Count -gt 0) {
          [PSCustomObject]@{
              BaseName        = $group.BaseName
              TopNeo42Version = $group.TopNeo42Version
              TopOrigVersion  = $group.TopOrigVersion
              PackagesVersion = if ($pkg) { $pkg.Version } else { "(nicht in Liste)" }
              Grund           = $reasons -join " | "
          }
      }
  }

  Write-Host "Phase 3 abgeschlossen: $($alerts.Count) Einträge mit Handlungsbedarf.`n"
  $alerts | Format-Table BaseName, TopNeo42Version, TopOrigVersion, PackagesVersion, Grund -AutoSize
  Read-Host