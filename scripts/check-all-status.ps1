$ErrorActionPreference = "Continue"

Write-Host "== Commands ==" -ForegroundColor Cyan
Get-Command openclaw, hermes, claude, node, npm, python -ErrorAction SilentlyContinue |
  Select-Object Name, Source, Version |
  Format-Table -AutoSize

Write-Host "`n== Processes ==" -ForegroundColor Cyan
Get-Process |
  Where-Object { $_.ProcessName -match 'openclaw|hermes|node|python|telegram|claude' } |
  Select-Object ProcessName, Id, Path |
  Format-Table -AutoSize

Write-Host "`n== OpenClaw port 18789 ==" -ForegroundColor Cyan
$openClawPort = Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue
if ($openClawPort) {
  $openClawPort | Select-Object LocalAddress, LocalPort, State, OwningProcess | Format-Table -AutoSize
} else {
  Write-Host "Port 18789 is not listening."
}

Write-Host "`n== OpenClaw status ==" -ForegroundColor Cyan
openclaw status

Write-Host "`n== OpenClaw channels ==" -ForegroundColor Cyan
openclaw channels status

Write-Host "`n== Hermes (project: Hermes + DeepSeek v4 + Telegram) ==" -ForegroundColor Cyan
Write-Host "Hermes project moved to: C:\Users\AI Developments\Documents\Working environment\Hermes + DeepSeek v4 + Telegram" -ForegroundColor Yellow
Write-Host "Run check-status there for Hermes diagnostics." -ForegroundColor Yellow
$hermesGatewayStatus = hermes gateway status 2>&1
Write-Host $hermesGatewayStatus

Write-Host "`n== Claude Code Telegram Bot ==" -ForegroundColor Cyan
Write-Host "Claude Code Telegram Bot running from: C:\Users\AI Developments\Documents\Working environment\Claude code + Telegram (Remote control)" -ForegroundColor Yellow
Write-Host "Run check-status there for Claude Telegram bot diagnostics." -ForegroundColor Yellow
Get-Service -Name ClaudeTelegramBot, ClaudeMcpHealthMonitor -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
