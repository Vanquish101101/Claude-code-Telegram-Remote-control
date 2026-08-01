$ErrorActionPreference = "Continue"

$pluginName = "telegram@claude-plugins-official"
$channelFlag = "plugin:$pluginName"

$sessions = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -eq "claude.exe" -and $_.CommandLine -match [regex]::Escape($channelFlag)
    }

if (-not $sessions) {
    Write-Host "No Claude Telegram channel sessions found." -ForegroundColor Yellow
    return
}

foreach ($session in $sessions) {
    Write-Host "Stopping Claude Telegram session PID $($session.ProcessId)..." -ForegroundColor Yellow
    Stop-Process -Id $session.ProcessId -Force
}

Write-Host "Stopped $($sessions.Count) Claude Telegram session(s)." -ForegroundColor Green

