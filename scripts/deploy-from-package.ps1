# deploy-from-package.ps1
# ASCII only - PS 5.1 reads .ps1 as ANSI without a UTF-8 BOM and Cyrillic breaks the parser.
#
# Deploys the global configuration from the migration package the user built
# before the move:  E:\Projects\___SYSTEM_DEPLOY  (see the RAZVERNUT .md in it).
# That package - not the old system disk - is the source of truth. F: is only a
# fallback for the two servers the package predates (smithery, knowledge-factory).
#
# Deliberately NOT a literal restore. Step 8 of the package registers Scheduled
# Tasks that fire on logon; this project now runs the bot as NSSM services with
# delayed auto-start instead, so those XMLs are ignored on purpose.
#
# Run it yourself: Claude's safety classifier refuses to move API keys around.
#
# Usage:  .\scripts\deploy-from-package.ps1
#         .\scripts\deploy-from-package.ps1 -WhatIfOnly    (report, change nothing)

param(
    [string]$Package  = "E:\Projects\___SYSTEM_DEPLOY",
    [string]$OldDisk  = "F:",
    [switch]$WhatIfOnly
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Package)) {
    Write-Host "Package not found: $Package" -ForegroundColor Red
    Write-Host "Is E: connected? Check: Get-PSDrive"
    exit 1
}

$oldHome = "C:\Users\Unknown"          # every path in the package is hardcoded to this
$newHome = $env:USERPROFILE
Write-Host "Package: $Package"
Write-Host "Rewriting paths: $oldHome  ->  $newHome`n" -ForegroundColor Cyan

# --- 1. Global Claude config ----------------------------------------------
# The package's settings.json carries the MCP servers WITH their API keys.
# Only mcpServers is taken: permissions/model on this machine are already set
# and deliberately differ (bypassPermissions, opus).

Write-Host "=== MCP servers ===" -ForegroundColor Cyan

$pkgSettings = Join-Path $Package "claude-global-config\settings.json"
$sources = @($pkgSettings)
# smithery + knowledge-factory were added after the package was built; they only
# exist in the old profile on F:.
$sources += (Join-Path $OldDisk "Users\Unknown\.claude.json")

$merged = [ordered]@{}
foreach ($s in $sources) {
    if (-not (Test-Path -LiteralPath $s)) { Write-Host "  skip (missing): $s" -ForegroundColor Yellow; continue }
    $j = Get-Content -LiteralPath $s -Raw | ConvertFrom-Json
    if (-not $j.mcpServers) { continue }
    foreach ($p in $j.mcpServers.PSObject.Properties) {
        if (-not $merged.Contains($p.Name)) { $merged[$p.Name] = $p.Value }
    }
}

# Rewrite the old user's paths, then keep only servers that actually resolve on
# this machine. The package's own notes flag this as a manual find-and-replace;
# doing it here is the whole point.
$keep = [ordered]@{}
foreach ($name in $merged.Keys) {
    $v = $merged[$name]

    if ($v.command -is [string] -and $v.command.StartsWith($oldHome)) {
        $v.command = $v.command.Replace($oldHome, $newHome)
    }
    if ($v.args) {
        $v.args = @($v.args | ForEach-Object {
            if ($_ -is [string] -and $_.Contains($oldHome)) { $_.Replace($oldHome, $newHome) } else { $_ }
        })
    }

    # http servers have no local path to verify
    if ($v.type -eq 'http') { $keep[$name] = $v; Write-Host ("  ok      {0,-20} http" -f $name) -ForegroundColor Green; continue }

    $bad = @()
    if ($v.command -match '^[a-zA-Z]:\\' -and -not (Test-Path -LiteralPath $v.command)) { $bad += $v.command }
    foreach ($a in @($v.args)) {
        if ($a -is [string] -and $a -match '^[a-zA-Z]:\\' -and -not (Test-Path -LiteralPath $a)) { $bad += $a }
    }

    if ($bad.Count -eq 0) {
        $keep[$name] = $v
        Write-Host ("  ok      {0,-20} {1}" -f $name, $v.command) -ForegroundColor Green
    } else {
        Write-Host ("  SKIP    {0,-20} missing: {1}" -f $name, ($bad -join '; ')) -ForegroundColor Yellow
    }
}

if (-not $WhatIfOnly -and $keep.Count -gt 0) {
    $target = "$env:USERPROFILE\.claude.json"
    $backup = "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item -LiteralPath $target -Destination $backup -Force
    Write-Host "  backup: $backup"

    $cur = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
    $final = [ordered]@{}
    if ($cur.mcpServers) { foreach ($p in $cur.mcpServers.PSObject.Properties) { $final[$p.Name] = $p.Value } }
    foreach ($k in $keep.Keys) { $final[$k] = $keep[$k] }

    $cur | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]$final) -Force
    $cur | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $target -Encoding utf8
    Write-Host ("  written: {0} server(s)" -f $final.Count) -ForegroundColor Green
}

# --- 2. Official Telegram channel -----------------------------------------

Write-Host "`n=== .claude\channels\telegram ===" -ForegroundColor Cyan
$src = Join-Path $Package "claude-global-config\channels-telegram"
$dst = "$env:USERPROFILE\.claude\channels\telegram"
if (Test-Path -LiteralPath $src) {
    if (-not $WhatIfOnly) { New-Item -ItemType Directory -Force -Path $dst | Out-Null }
    Get-ChildItem -LiteralPath $src -File -Force | ForEach-Object {
        if (-not $WhatIfOnly) { Copy-Item -LiteralPath $_.FullName -Destination $dst -Force }
        Write-Host ("  {0,-14} {1,6} b" -f $_.Name, $_.Length) -ForegroundColor Green
    }
} else { Write-Host "  not found: $src" -ForegroundColor Yellow }

# --- 3. Git identity -------------------------------------------------------

Write-Host "`n=== .gitconfig ===" -ForegroundColor Cyan
$src = Join-Path $Package "git-config\.gitconfig"
$dst = "$env:USERPROFILE\.gitconfig"
if (Test-Path -LiteralPath $src) {
    if (Test-Path -LiteralPath $dst) {
        Write-Host "  already present, left alone (package copy: $src)"
    } else {
        if (-not $WhatIfOnly) { Copy-Item -LiteralPath $src -Destination $dst -Force }
        Write-Host "  installed" -ForegroundColor Green
    }
} else { Write-Host "  not found" -ForegroundColor Yellow }

# --- 4. Keys and notes off the old disk ------------------------------------
# Not in the package; the user asked for these by name.

Write-Host "`n=== Documents\Project settings ===" -ForegroundColor Cyan
$src = Join-Path $OldDisk "Users\Unknown\Documents\Project settings"
$dst = "$env:USERPROFILE\Documents\Project settings"
if (Test-Path -LiteralPath $src) {
    if (-not $WhatIfOnly) { New-Item -ItemType Directory -Force -Path $dst | Out-Null }
    Get-ChildItem -LiteralPath $src -File -Force | ForEach-Object {
        if (-not $WhatIfOnly) { Copy-Item -LiteralPath $_.FullName -Destination $dst -Force }
        Write-Host ("  {0,-40} {1,7} b" -f $_.Name, $_.Length) -ForegroundColor Green
    }
} else { Write-Host "  old disk not connected - skipped" -ForegroundColor Yellow }

Write-Host "`nVerify with:  claude mcp list" -ForegroundColor Cyan
Write-Host "Then:         .\scripts\set-service-account.ps1   (run the bot as your account)"
