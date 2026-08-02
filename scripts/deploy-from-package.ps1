# deploy-from-package.ps1
# ASCII only - PS 5.1 reads .ps1 as ANSI without a UTF-8 BOM and Cyrillic breaks the parser.
#
# Builds C:\MCP\config\mcp-servers.json (the master list) from the migration package
# the user assembled before the move - E:\Projects\___SYSTEM_DEPLOY - and then
# generates %USERPROFILE%\.claude.json from that master.
#
# The master is the single source of truth. .claude.json cannot move (every Claude
# tool looks for it in the profile), so it becomes generated rather than hand-edited.
#
# Deliberate departures from the package's own instructions:
#   - Step 8 registers Scheduled Tasks that fire on logon. This project uses NSSM
#     services with delayed auto-start instead.
#   - The package invokes npm servers as `npx -y <pkg>@latest`, which re-downloads
#     on every launch and can silently update mid-session. They are installed once
#     under C:\MCP\servers with pinned versions, and the config points at those.
#
# Run it yourself: Claude's safety classifier refuses to move API keys around.
#
# Usage:  .\scripts\deploy-from-package.ps1
#         .\scripts\deploy-from-package.ps1 -WhatIfOnly    (report, change nothing)

param(
    [string]$Package = "E:\Projects\___SYSTEM_DEPLOY",
    [string]$OldDisk = "F:",
    [string]$McpHome = $(if ($env:MCP_HOME) { $env:MCP_HOME } else { "C:\MCP" }),
    [switch]$WhatIfOnly
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Package)) {
    Write-Host "Package not found: $Package  (is E: connected?)" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $McpHome)) {
    Write-Host "MCP home not found: $McpHome" -ForegroundColor Red
    exit 1
}

$oldHome = "C:\Users\Unknown"          # every path in the package is hardcoded to this
$newHome = $env:USERPROFILE
$bin     = Join-Path $McpHome "servers\node_modules\.bin"

Write-Host "Package:  $Package"
Write-Host "MCP home: $McpHome"
Write-Host "Rewriting paths: $oldHome -> $newHome`n" -ForegroundColor Cyan

# npx package name -> the executable installed under C:\MCP\servers
$npxToBin = @{
    "@supabase/mcp-server-supabase" = "mcp-server-supabase"
    "@playwright/mcp"               = "playwright-mcp"
    "@upstash/context7-mcp"         = "context7-mcp"
    "@apify/actors-mcp-server"      = "actors-mcp-server"
    "@perplexity-ai/mcp-server"     = "perplexity-mcp"
    "firecrawl-mcp"                 = "firecrawl-mcp"
}

# --- 1. Collect server definitions ----------------------------------------

Write-Host "=== MCP servers ===" -ForegroundColor Cyan

$sources = @(
    (Join-Path $Package "claude-global-config\settings.json"),
    # smithery + knowledge-factory postdate the package; they exist only in the
    # old profile on F:.
    (Join-Path $OldDisk "Users\Unknown\.claude.json")
)

$merged = [ordered]@{}
foreach ($s in $sources) {
    if (-not (Test-Path -LiteralPath $s)) { Write-Host "  skip (missing): $s" -ForegroundColor Yellow; continue }
    $j = Get-Content -LiteralPath $s -Raw | ConvertFrom-Json
    if (-not $j.mcpServers) { continue }
    foreach ($p in $j.mcpServers.PSObject.Properties) {
        if (-not $merged.Contains($p.Name)) { $merged[$p.Name] = $p.Value }
    }
}

$keep = [ordered]@{}
foreach ($name in $merged.Keys) {
    $v = $merged[$name]

    # http servers live remotely - nothing local to verify or relocate
    if ($v.type -eq 'http') {
        $keep[$name] = $v
        Write-Host ("  ok    {0,-20} http  {1}" -f $name, $v.url) -ForegroundColor Green
        continue
    }

    # npx -> the pinned local install
    if ($v.command -eq 'npx') {
        $pkg = @($v.args | Where-Object { $_ -notmatch '^-' } | Select-Object -First 1)
        $pkg = ($pkg -replace '@latest$','') -replace '@[\d.]+$',''
        $exe = $npxToBin[$pkg]
        if (-not $exe) {
            Write-Host ("  SKIP  {0,-20} unknown npm package: {1}" -f $name, $pkg) -ForegroundColor Yellow
            continue
        }
        $cmdPath = Join-Path $bin "$exe.cmd"
        if (-not (Test-Path -LiteralPath $cmdPath)) {
            Write-Host ("  SKIP  {0,-20} not installed: {1}" -f $name, $cmdPath) -ForegroundColor Yellow
            Write-Host ("        fix with: cd $McpHome\servers; npm install")
            continue
        }
        $v.command = $cmdPath
        # Drop npx's own flags (-y, --prefer-offline, the package name); keep the
        # server's real arguments, if it had any after the package spec.
        $rest = @()
        $seenPkg = $false
        foreach ($a in @($v.args)) {
            if (-not $seenPkg) { if ($a -notmatch '^-') { $seenPkg = $true }; continue }
            $rest += $a
        }
        $v.args = $rest
        $keep[$name] = $v
        Write-Host ("  ok    {0,-20} {1}" -f $name, $cmdPath) -ForegroundColor Green
        continue
    }

    # everything else: rewrite the old user's paths, then verify they resolve
    if ($v.command -is [string] -and $v.command.Contains($oldHome)) {
        $v.command = $v.command.Replace($oldHome, $newHome)
    }
    if ($v.args) {
        $v.args = @($v.args | ForEach-Object {
            if ($_ -is [string] -and $_.Contains($oldHome)) { $_.Replace($oldHome, $newHome) } else { $_ }
        })
    }

    $bad = @()
    if ($v.command -match '^[a-zA-Z]:\\' -and -not (Test-Path -LiteralPath $v.command)) { $bad += $v.command }
    foreach ($a in @($v.args)) {
        if ($a -is [string] -and $a -match '^[a-zA-Z]:\\' -and -not (Test-Path -LiteralPath $a)) { $bad += $a }
    }

    if ($bad.Count -eq 0) {
        $keep[$name] = $v
        Write-Host ("  ok    {0,-20} {1}" -f $name, $v.command) -ForegroundColor Green
    } else {
        Write-Host ("  SKIP  {0,-20} missing: {1}" -f $name, ($bad -join '; ')) -ForegroundColor Yellow
    }
}

# --- 2. Write the master, then generate .claude.json from it ---------------

if (-not $WhatIfOnly -and $keep.Count -gt 0) {

    $master = Join-Path $McpHome "config\mcp-servers.json"
    if (Test-Path -LiteralPath $master) {
        Copy-Item -LiteralPath $master -Destination "$master.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
    }
    [pscustomobject]@{
        _comment    = "Master list. Edit here, then run deploy-from-package.ps1 to propagate."
        _generated  = (Get-Date).ToString("s")
        mcpServers  = [pscustomobject]$keep
    } | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $master -Encoding utf8
    Write-Host "`n  master: $master" -ForegroundColor Green

    $target = "$env:USERPROFILE\.claude.json"
    Copy-Item -LiteralPath $target -Destination "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
    $cur = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
    # The master is authoritative for MCP: servers dropped from it should
    # disappear here too, otherwise the two quietly diverge.
    $cur | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]$keep) -Force
    $cur | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $target -Encoding utf8
    Write-Host ("  generated: {0}  ({1} servers)" -f $target, $keep.Count) -ForegroundColor Green
}

# --- 3. Official Telegram channel -----------------------------------------

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

# --- 4. Git identity -------------------------------------------------------

Write-Host "`n=== .gitconfig ===" -ForegroundColor Cyan
$src = Join-Path $Package "git-config\.gitconfig"
$dst = "$env:USERPROFILE\.gitconfig"
if (Test-Path -LiteralPath $src) {
    if (Test-Path -LiteralPath $dst) {
        Write-Host "  already present, left alone"
    } else {
        if (-not $WhatIfOnly) { Copy-Item -LiteralPath $src -Destination $dst -Force }
        Write-Host "  installed" -ForegroundColor Green
    }
} else { Write-Host "  not found" -ForegroundColor Yellow }

# --- 5. Keys and notes off the old disk ------------------------------------

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
