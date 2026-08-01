param(
  [switch]$Debug
)

$ErrorActionPreference = "Stop"

$botExe = "C:\Users\AI Developments\AppData\Local\hermes\hermes-agent\venv\Scripts\claude-telegram-bot.exe"
$configFile = "C:\Users\AI Developments\Documents\Working environment\Claude code + Telegram (Remote control)\.claude-telegram\.env"
$dataDir = "C:\Users\AI Developments\Documents\Working environment\Claude code + Telegram (Remote control)\.claude-telegram"

if (-not (Test-Path -LiteralPath $botExe)) {
  Write-Host "claude-telegram-bot.exe not found. Reinstall:" -ForegroundColor Red
  Write-Host "pip install git+https://github.com/RichardAtCT/claude-code-telegram.git@v1.3.0"
  exit 1
}

if (-not (Test-Path -LiteralPath $configFile)) {
  Write-Host "Config not found: $configFile" -ForegroundColor Red
  exit 1
}

Push-Location $dataDir

Write-Host "Starting Claude Code Telegram bot (@foresight_project_claudecode_bot)..." -ForegroundColor Cyan
Write-Host "Config: $configFile" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor Gray

$env:ENV_FILE = $configFile

if ($Debug) {
  & $botExe --config-file $configFile --debug
} else {
  & $botExe --config-file $configFile
}

Pop-Location
