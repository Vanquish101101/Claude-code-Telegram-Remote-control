# migrate-from-old-disk.ps1
# ASCII only - PS 5.1 reads .ps1 as ANSI without a UTF-8 BOM and Cyrillic breaks the parser.
#
# Pulls two things off the old system disk (F:) onto the new one:
#   1. Documents\Project settings  ->  C:\Users\AI Developments\Documents\Project settings
#      (API Keys.txt, MCP key connection.txt, Hermes stack notes, chat export)
#   2. MCP server definitions from the old profile -> new %USERPROFILE%\.claude.json
#
# Run it yourself: Claude's safety classifier refuses to move API keys around,
# so this stays a manual, explicit action.
#
# Usage:  .\scripts\migrate-from-old-disk.ps1
#         .\scripts\migrate-from-old-disk.ps1 -SkipFiles     (MCP config only)
#         .\scripts\migrate-from-old-disk.ps1 -SkipMcp       (files only)

param(
    [string]$OldDisk = "F:",
    [switch]$SkipFiles,
    [switch]$SkipMcp
)

$ErrorActionPreference = "Stop"

$oldProfile = Join-Path $OldDisk "Users\Unknown"
if (-not (Test-Path -LiteralPath $oldProfile)) {
    Write-Host "Old profile not found: $oldProfile" -ForegroundColor Red
    Write-Host "Is the old disk still connected? Check: Get-PSDrive"
    exit 1
}

# --- 1. Project settings folder -------------------------------------------

if (-not $SkipFiles) {
    Write-Host "`n=== Project settings ===" -ForegroundColor Cyan
    $src = Join-Path $oldProfile "Documents\Project settings"
    $dst = "$env:USERPROFILE\Documents\Project settings"

    if (Test-Path -LiteralPath $src) {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        # Files only - the old .git in there is Codex leftovers, not worth carrying over.
        Get-ChildItem -LiteralPath $src -File -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
            Write-Host ("  copied  {0,-40} {1,8} b" -f $_.Name, $_.Length) -ForegroundColor Green
        }
        Write-Host "  -> $dst"
    } else {
        Write-Host "  not found: $src" -ForegroundColor Yellow
    }
}

# --- 2. MCP servers --------------------------------------------------------

if (-not $SkipMcp) {
    Write-Host "`n=== MCP servers ===" -ForegroundColor Cyan

    # Only servers that actually work on the new machine. Excluded on purpose:
    #   whisper        - script lives under the old user's Marketing agency project
    #   deepgram/redis - .exe under C:\Users\Unknown\...\pythoncore-3.14-64
    #   video-pipeline - old Projects path, that project is not deployed here yet
    $portable = @('supabase','playwright','context7','apify','perplexity',
                  'firecrawl','n8n','smithery','knowledge-factory')

    $sources = @(
        (Join-Path $oldProfile ".claude\settings.json"),
        (Join-Path $oldProfile ".claude.json")
    )

    $merged = [ordered]@{}
    foreach ($s in $sources) {
        if (-not (Test-Path -LiteralPath $s)) { continue }
        $j = Get-Content -LiteralPath $s -Raw | ConvertFrom-Json
        if (-not $j.mcpServers) { continue }
        foreach ($p in $j.mcpServers.PSObject.Properties) {
            if ($portable -contains $p.Name -and -not $merged.Contains($p.Name)) {
                $merged[$p.Name] = $p.Value
                Write-Host ("  taking  {0}" -f $p.Name) -ForegroundColor Green
            }
        }
    }

    if ($merged.Count -eq 0) {
        Write-Host "  nothing to migrate" -ForegroundColor Yellow
    } else {
        $target = "$env:USERPROFILE\.claude.json"
        $backup = "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item -LiteralPath $target -Destination $backup -Force
        Write-Host "  backup: $backup"

        $cur = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
        # Merge into whatever is already there rather than replacing wholesale.
        $existing = [ordered]@{}
        if ($cur.mcpServers) {
            foreach ($p in $cur.mcpServers.PSObject.Properties) { $existing[$p.Name] = $p.Value }
        }
        foreach ($k in $merged.Keys) { $existing[$k] = $merged[$k] }

        $cur | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]$existing) -Force
        $cur | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $target -Encoding utf8

        Write-Host ("  written: {0} server(s) -> {1}" -f $existing.Count, $target) -ForegroundColor Green
    }
}

# --- 3. Official Telegram channel config -----------------------------------

if (-not $SkipFiles) {
    Write-Host "`n=== .claude\channels\telegram ===" -ForegroundColor Cyan
    # mcp-health-monitor.ps1 falls back to this .env when the project one is missing,
    # and the official telegram plugin reads it. Holds the bot token, hence manual.
    $src = Join-Path $oldProfile ".claude\channels\telegram"
    $dst = "$env:USERPROFILE\.claude\channels\telegram"

    if (Test-Path -LiteralPath $src) {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Get-ChildItem -LiteralPath $src -File -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
            Write-Host ("  copied  {0,-20} {1,6} b" -f $_.Name, $_.Length) -ForegroundColor Green
        }
        Write-Host "  -> $dst"
    } else {
        Write-Host "  not found: $src" -ForegroundColor Yellow
    }
}

Write-Host "`nVerify with:  claude mcp list" -ForegroundColor Cyan
Write-Host "Servers needing a rebuild on this machine: whisper, deepgram, redis, video-pipeline"
