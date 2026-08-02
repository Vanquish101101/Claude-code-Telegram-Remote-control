# update-bot.ps1
# ASCII only - PS 5.1 reads .ps1 as ANSI without a UTF-8 BOM and Cyrillic breaks the parser.
#
# Rebuilds the bot from bot-src into the project venv and restarts the service.
# Run this after any change to bot-src.
#
# Needs an elevated PowerShell: stopping a Windows service requires it, and the
# install cannot overwrite claude-telegram-bot.exe while the bot is holding it.
#
# Usage:  .\scripts\update-bot.ps1

$ErrorActionPreference = "Stop"

$proj = Split-Path -Parent $PSScriptRoot
$venv = Join-Path $proj ".venv"
$src  = Join-Path $proj "bot-src"
$svc  = "ClaudeTelegramBot"

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Needs an elevated PowerShell (Run as administrator)." -ForegroundColor Red
    exit 1
}
foreach ($p in @($venv, $src)) {
    if (-not (Test-Path -LiteralPath $p)) { Write-Host "Missing: $p" -ForegroundColor Red; exit 1 }
}

# Compile first: a syntax error caught here costs nothing, the same error caught
# after the service is already down costs downtime.
Write-Host "Checking syntax..." -ForegroundColor Cyan
& "$venv\Scripts\python.exe" -m compileall -q "$src\src" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  syntax errors - nothing was changed" -ForegroundColor Red
    exit 1
}
Write-Host "  ok" -ForegroundColor Green

$wasRunning = (Get-Service -Name $svc).Status -eq "Running"
if ($wasRunning) {
    Write-Host "`nStopping $svc..." -ForegroundColor Cyan
    Stop-Service -Name $svc -Force
    # The service manager returns before the process has released its files.
    for ($i = 0; $i -lt 20; $i++) {
        if (-not (Get-Process claude-telegram-bot -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Milliseconds 500
    }
    Write-Host "  stopped"
}

try {
    Write-Host "`nInstalling from bot-src..." -ForegroundColor Cyan
    # --no-deps: dependencies are already pinned in the venv and unchanged;
    # reinstalling them turns a 5-second update into a 2-minute one.
    & "$venv\Scripts\python.exe" -m pip install --quiet --force-reinstall --no-deps $src
    if ($LASTEXITCODE -ne 0) { throw "pip install failed with exit code $LASTEXITCODE" }
    Write-Host "  installed" -ForegroundColor Green

    $ver = & "$venv\Scripts\python.exe" -c "import importlib.metadata as m; print(m.version('claude-code-telegram'))"
    Write-Host "  version: $ver"
}
finally {
    if ($wasRunning) {
        Write-Host "`nStarting $svc..." -ForegroundColor Cyan
        Start-Service -Name $svc
        Start-Sleep -Seconds 6
        $s = Get-Service -Name $svc
        $color = if ($s.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host "  $($s.Status)" -ForegroundColor $color
    }
}

Write-Host "`nRecent log:" -ForegroundColor Cyan
$logDir = "$env:LOCALAPPDATA\foresight-bots\logs\claude-telegram"
$log = Get-ChildItem $logDir -Filter "service-stdout*" -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
    Get-Content $log.FullName -Tail 5 | ForEach-Object { "  $_" }
} else {
    Write-Host "  no log yet"
}
