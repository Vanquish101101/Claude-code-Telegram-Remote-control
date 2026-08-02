# Installs the legacy Telegram bot and the MCP Health Monitor as real Windows services
# via NSSM, replacing the old Scheduled Tasks. RUN AS ADMINISTRATOR.
#
# NOTE: ASCII-only on purpose. Windows PowerShell 5.1 reads .ps1 files as ANSI unless
# they have a UTF-8 BOM, so Cyrillic here would break the parser.

$nssm = "C:\Users\AI Developments\AppData\Local\Microsoft\WinGet\Packages\NSSM.NSSM_Microsoft.Winget.Source_8wekyb3d8bbwe\nssm-2.24-101-g897c7ad\win64\nssm.exe"
$projectDir = "C:\Users\AI Developments\Documents\Working environment\Claude code + Telegram (Remote control)"
$botExe = "C:\Users\AI Developments\Documents\Working environment\Claude code + Telegram (Remote control)\.venv\Scripts\claude-telegram-bot.exe"
$configFile = "$projectDir\.claude-telegram\.env"
$logDir = "C:\Users\AI Developments\AppData\Local\foresight-bots\logs\claude-telegram"

if (-not (Test-Path -LiteralPath $nssm))      { Write-Host "NSSM not found: $nssm" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $botExe))    { Write-Host "Bot exe not found: $botExe" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $configFile)){ Write-Host "Config not found: $configFile" -ForegroundColor Red; exit 1 }
New-Item -ItemType Directory -Force $logDir | Out-Null

# Remove any previous registrations so this script is safe to re-run
foreach ($svc in @("ClaudeTelegramBot","ClaudeMcpHealthMonitor")) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Write-Host "Removing existing service $svc ..." -ForegroundColor Yellow
        & $nssm stop   $svc confirm | Out-Null
        & $nssm remove $svc confirm | Out-Null
        Start-Sleep -Seconds 2
    }
}

# === Service 1: the bot itself ===
& $nssm install ClaudeTelegramBot $botExe "--config-file `"$configFile`"" | Out-Null
& $nssm set ClaudeTelegramBot AppDirectory     "$projectDir\.claude-telegram" | Out-Null
& $nssm set ClaudeTelegramBot AppStdout        "$logDir\service-stdout.log"   | Out-Null
& $nssm set ClaudeTelegramBot AppStderr        "$logDir\service-stderr.log"   | Out-Null
& $nssm set ClaudeTelegramBot AppRotateFiles   1        | Out-Null
& $nssm set ClaudeTelegramBot AppRotateOnline  1        | Out-Null
& $nssm set ClaudeTelegramBot AppRotateBytes   10485760 | Out-Null
& $nssm set ClaudeTelegramBot Start            SERVICE_AUTO_START | Out-Null
& $nssm set ClaudeTelegramBot AppExit Default  Restart  | Out-Null
& $nssm set ClaudeTelegramBot AppRestartDelay  10000    | Out-Null
& $nssm set ClaudeTelegramBot DisplayName      "Claude Code Telegram Bot (Remote control)" | Out-Null
& $nssm set ClaudeTelegramBot Description      "Legacy Telegram bridge to Claude Code CLI (subscription mode)" | Out-Null

# === Service 2: MCP Health Monitor / watchdog ===
& $nssm install ClaudeMcpHealthMonitor "powershell.exe" "-NonInteractive -ExecutionPolicy Bypass -File `"$projectDir\scripts\mcp-health-monitor.ps1`"" | Out-Null
& $nssm set ClaudeMcpHealthMonitor AppStdout       "$logDir\monitor-stdout.log" | Out-Null
& $nssm set ClaudeMcpHealthMonitor AppStderr       "$logDir\monitor-stderr.log" | Out-Null
& $nssm set ClaudeMcpHealthMonitor AppRotateFiles  1        | Out-Null
& $nssm set ClaudeMcpHealthMonitor AppRotateOnline 1        | Out-Null
& $nssm set ClaudeMcpHealthMonitor AppRotateBytes  10485760 | Out-Null
& $nssm set ClaudeMcpHealthMonitor Start           SERVICE_AUTO_START | Out-Null
& $nssm set ClaudeMcpHealthMonitor AppExit Default Restart  | Out-Null
& $nssm set ClaudeMcpHealthMonitor AppRestartDelay 10000    | Out-Null
& $nssm set ClaudeMcpHealthMonitor DisplayName     "Claude MCP Health Monitor" | Out-Null
& $nssm set ClaudeMcpHealthMonitor Description     "Watchdog for the Telegram bot and MCP servers, alerts via Telegram" | Out-Null

Write-Host "`nStarting services..." -ForegroundColor Cyan
Start-Service ClaudeTelegramBot
Start-Sleep -Seconds 8
Start-Service ClaudeMcpHealthMonitor
Start-Sleep -Seconds 3

Write-Host "`nResult:" -ForegroundColor Cyan
Get-Service ClaudeTelegramBot, ClaudeMcpHealthMonitor | Format-Table Name, Status, StartType -AutoSize
