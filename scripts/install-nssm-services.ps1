# Устанавливает legacy Telegram-бота и MCP Health Monitor как настоящие Windows-сервисы
# через NSSM — вместо Scheduled Tasks. ЗАПУСКАТЬ ОТ ИМЕНИ АДМИНИСТРАТОРА.

$nssm = "C:\Users\AI Developments\AppData\Local\Microsoft\WinGet\Packages\NSSM.NSSM_Microsoft.Winget.Source_8wekyb3d8bbwe\nssm-2.24-101-g897c7ad\win64\nssm.exe"
$projectDir = "C:\Users\AI Developments\Documents\Working environment\Claude code + Telegram [Remote control]"
$botExe = "C:\Users\AI Developments\AppData\Local\hermes\hermes-agent\venv\Scripts\claude-telegram-bot.exe"
$configFile = "$projectDir\.claude-telegram\.env"
$logDir = "C:\Users\AI Developments\AppData\Local\foresight-bots\logs\claude-telegram"
New-Item -ItemType Directory -Force $logDir | Out-Null

# === Сервис 1: сам бот ===
& $nssm install ClaudeTelegramBot $botExe "--config-file `"$configFile`""
& $nssm set ClaudeTelegramBot AppDirectory "$projectDir\.claude-telegram"
& $nssm set ClaudeTelegramBot AppStdout "$logDir\service-stdout.log"
& $nssm set ClaudeTelegramBot AppStderr "$logDir\service-stderr.log"
& $nssm set ClaudeTelegramBot AppRotateFiles 1
& $nssm set ClaudeTelegramBot AppRotateOnline 1
& $nssm set ClaudeTelegramBot AppRotateBytes 10485760
& $nssm set ClaudeTelegramBot Start SERVICE_AUTO_START
& $nssm set ClaudeTelegramBot AppExit Default Restart
& $nssm set ClaudeTelegramBot AppRestartDelay 10000
& $nssm set ClaudeTelegramBot DisplayName "Claude Code Telegram Bot (Telemost)"
& $nssm set ClaudeTelegramBot Description "Legacy Telegram bridge to Claude Code CLI (subscription mode)"

# === Сервис 2: MCP Health Monitor / watchdog ===
& $nssm install ClaudeMcpHealthMonitor "powershell.exe" "-NonInteractive -ExecutionPolicy Bypass -File `"$projectDir\scripts\mcp-health-monitor.ps1`""
& $nssm set ClaudeMcpHealthMonitor AppStdout "$logDir\monitor-stdout.log"
& $nssm set ClaudeMcpHealthMonitor AppStderr "$logDir\monitor-stderr.log"
& $nssm set ClaudeMcpHealthMonitor AppRotateFiles 1
& $nssm set ClaudeMcpHealthMonitor AppRotateOnline 1
& $nssm set ClaudeMcpHealthMonitor AppRotateBytes 10485760
& $nssm set ClaudeMcpHealthMonitor Start SERVICE_AUTO_START
& $nssm set ClaudeMcpHealthMonitor AppExit Default Restart
& $nssm set ClaudeMcpHealthMonitor AppRestartDelay 10000
& $nssm set ClaudeMcpHealthMonitor DisplayName "Claude MCP Health Monitor"
& $nssm set ClaudeMcpHealthMonitor Description "Watchdog for Claude Telegram bot + MCP servers, alerts via Telegram"

Write-Host "`nГотово. Проверка:" -ForegroundColor Cyan
Get-Service ClaudeTelegramBot, ClaudeMcpHealthMonitor | Format-Table Name, Status, StartType -AutoSize

Write-Host "`nЗапуск сервисов:" -ForegroundColor Cyan
Start-Service ClaudeTelegramBot
Start-Sleep -Seconds 5
Start-Service ClaudeMcpHealthMonitor
Start-Sleep -Seconds 3
Get-Service ClaudeTelegramBot, ClaudeMcpHealthMonitor | Format-Table Name, Status, StartType -AutoSize
