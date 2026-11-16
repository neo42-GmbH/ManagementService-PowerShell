#requires -version 5
<#
.SYNOPSIS
	Refreshes the local snapshot of the documented MMS API and rebuilds docs\api-catalog.md.
.DESCRIPTION
	The swagger documentation of the MMS server lists exactly those routes that
	neo42 considers safe for automation. It is only served when the server
	setting 'EnableApiDocumentation' is active.

	This script downloads https://<server>/docs/v1/swagger and writes:
		docs\swagger-v1.json       raw document, used by Find-MmsApiRoute
		docs\swagger-v1.meta.json  server version and date of the snapshot
		docs\api-catalog.md        readable route catalog grouped by plug-in

	Run it after an MMS update, or when a route you need is missing from the catalog.
.PARAMETER ServerName
	Base address of the API, for example 'https://server.domain:4242'.
	Defaults to the server resolved by the module (session, environment, default profile).
.PARAMETER ConnectionProfile
	Name of a stored connection profile to read the address from.
.EXAMPLE
	.\Update-MmsApiCatalog.ps1
.EXAMPLE
	.\Update-MmsApiCatalog.ps1 -ServerName 'https://server.domain:4242'
#>
[CmdletBinding()]
param (
	[Parameter()]
	[string]
	$ServerName,

	[Parameter()]
	[string]
	$ConnectionProfile
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$moduleRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module (Join-Path -Path $moduleRoot -ChildPath 'Neo42.MmsApi.psd1') -Force

$docsPath = Join-Path -Path $moduleRoot -ChildPath 'docs'
if (-not (Test-Path -LiteralPath $docsPath)) {
	New-Item -ItemType Directory -Path $docsPath -Force | Out-Null
}

if (-not [string]::IsNullOrWhiteSpace($ServerName)) {
	$connection = Connect-MmsApi -ServerName $ServerName -PassThru
}
elseif (-not [string]::IsNullOrWhiteSpace($ConnectionProfile)) {
	$connection = Connect-MmsApi -ConnectionProfile $ConnectionProfile -PassThru
}
else {
	$connection = Get-MmsApiSession
}
if ($null -eq $connection) {
	throw "No MMS server known. Pass -ServerName or run Connect-MmsApi first."
}

$serverVersion = Get-MmsServerVersion -Session $connection
$swaggerUrl = '{0}/docs/v1/swagger' -f $connection.ServerName

Write-Verbose "Downloading $swaggerUrl"
try {
	$swaggerContent = Invoke-MmsApiRequest -Path '/docs/v1/swagger' -Session $connection -TimeoutSec 120 -Raw -SkipRouteCheck
}
catch {
	throw ("Could not download the API documentation from '$swaggerUrl': $($_.Exception.Message). " +
		"Activate the server setting 'EnableApiDocumentation' and try again.")
}

# The document carries the host it was fetched from in its own 'host' property,
# and this snapshot ships in a public repository - so the real server name is
# replaced with a placeholder before anything is written. Targeted string
# replacement rather than ConvertTo-Json, because re-serializing a 170 kB
# document would reformat all of it and make every future diff useless.
# Tests\Unit\ApiSurface.Tests.ps1 asserts the placeholder is what landed.
$hostPlaceholder = 'server.domain:4242'
$hostMatches = [regex]::Matches($swaggerContent, '"host"\s*:\s*"[^"]*"')
if ($hostMatches.Count -ne 1) {
	throw ("Expected exactly one 'host' property in the swagger document, found $($hostMatches.Count). " +
		"Refusing to write the snapshot: it would carry the real server name into a public repository.")
}
$swaggerContent = [regex]::Replace($swaggerContent, '("host"\s*:\s*")[^"]*(")', ('${1}' + $hostPlaceholder + '${2}'))

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$swaggerPath = Join-Path -Path $docsPath -ChildPath 'swagger-v1.json'
$metaPath = Join-Path -Path $docsPath -ChildPath 'swagger-v1.meta.json'

# Keep the snapshot that is about to be overwritten. Comparing two snapshots is
# how breaking changes of a new MMS version are found (see Tests\README.md), and
# the old document only exists here.
if (Test-Path -LiteralPath $swaggerPath) {
	$previousVersion = 'unknown'
	if (Test-Path -LiteralPath $metaPath) {
		try {
			$previousVersion = (Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json).ServerVersion
		}
		catch {
			Write-Warning "Could not read the previous snapshot metadata: $($_.Exception.Message)"
		}
	}

	$baselinePath = Join-Path -Path $moduleRoot -ChildPath 'Tests\Baseline'
	if (-not (Test-Path -LiteralPath $baselinePath)) {
		New-Item -ItemType Directory -Path $baselinePath -Force | Out-Null
	}

	Copy-Item -LiteralPath $swaggerPath -Destination (Join-Path -Path $baselinePath -ChildPath ("swagger-$previousVersion.json")) -Force
	if (Test-Path -LiteralPath $metaPath) {
		Copy-Item -LiteralPath $metaPath -Destination (Join-Path -Path $baselinePath -ChildPath ("swagger-$previousVersion.meta.json")) -Force
	}
	Write-Host "Previous snapshot kept as Tests\Baseline\swagger-$previousVersion.json"
}

[System.IO.File]::WriteAllText($swaggerPath, $swaggerContent, $utf8NoBom)

$document = $swaggerContent | ConvertFrom-Json
$routes = @(& (Get-Module Neo42.MmsApi) { param($doc) ConvertTo-MmsRouteObject -SwaggerDocument $doc } $document)

$fetchedAt = Get-Date

# The snapshot ships in a public repository, so it must not carry the host name
# or the account it was taken with.
$meta = [pscustomobject]@{
	ServerVersion  = [string]$serverVersion
	SwaggerVersion = $document.swagger
	ApiVersion     = $document.info.version
	FetchedAt      = $fetchedAt.ToString('o')
	PathCount      = @($document.paths.PSObject.Properties).Count
	OperationCount = $routes.Count
}
[System.IO.File]::WriteAllText(
	(Join-Path -Path $docsPath -ChildPath 'swagger-v1.meta.json'),
	($meta | ConvertTo-Json -Depth 4),
	$utf8NoBom)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# MMS API catalog (documented routes)')
$lines.Add('')
$lines.Add('> Generated by ``Tools\Update-MmsApiCatalog.ps1`` - do not edit by hand.')
$lines.Add('')
$lines.Add("- MMS server version: **$serverVersion**")
$lines.Add("- Snapshot taken: **$($fetchedAt.ToString('yyyy-MM-dd HH:mm'))**")
$lines.Add("- Source: ``/docs/v1/swagger`` of an MMS $serverVersion server")
$lines.Add("- Operations: **$($routes.Count)** on $($meta.PathCount) paths, in $(@($routes | Group-Object Tag).Count) groups")
$lines.Add('')
$lines.Add('Every route listed here is released by neo42 for automation. Routes that are')
$lines.Add('**not** listed here exist but are undocumented: they can change or disappear in')
$lines.Add('any MMS release without notice, so prefer a documented route whenever possible.')
$lines.Add('')
$lines.Add('All operations require the header ``X-Neo42-Auth: Admin`` and an authenticated')
$lines.Add('caller. ``Invoke-MmsApiRequest`` handles both, see ``Connect-MmsApi``.')
$lines.Add('')
$lines.Add('## Groups')
$lines.Add('')
$lines.Add('| Group | GET | Write | Total |')
$lines.Add('| --- | ---: | ---: | ---: |')
foreach ($group in $routes | Group-Object Tag | Sort-Object Name) {
	$readCount = @($group.Group | Where-Object { $_.Method -eq 'GET' }).Count
	$writeCount = $group.Count - $readCount
	$lines.Add(('| {0} | {1} | {2} | {3} |' -f $group.Name, $readCount, $writeCount, $group.Count))
}
$lines.Add('')

foreach ($group in $routes | Group-Object Tag | Sort-Object Name) {
	$lines.Add(('## {0}' -f $group.Name))
	$lines.Add('')
	$lines.Add('| Method | Path | Query | Body | Returns | Operation |')
	$lines.Add('| --- | --- | --- | --- | --- | --- |')
	foreach ($route in $group.Group | Sort-Object Path, Method) {
		$query = if (@($route.QueryParameters).Count -gt 0) { '`' + ((@($route.QueryParameters) | Sort-Object) -join '`, `') + '`' } else { '-' }
		$body = if ($route.BodySchema) { '`' + $route.BodySchema + '`' } else { '-' }
		$returns = if ($route.ResponseSchema) { '`' + $route.ResponseSchema + '`' } else { '-' }
		$lines.Add(('| {0} | `{1}` | {2} | {3} | {4} | {5} |' -f $route.Method, $route.Path, $query, $body, $returns, $route.OperationId))
	}
	$lines.Add('')
}

$catalogPath = Join-Path -Path $docsPath -ChildPath 'api-catalog.md'
[System.IO.File]::WriteAllLines($catalogPath, $lines, $utf8NoBom)

Write-Host "Catalog updated: $catalogPath"
Write-Host "  MMS $serverVersion, $($routes.Count) documented operations, $(@($routes | Group-Object Tag).Count) groups"
