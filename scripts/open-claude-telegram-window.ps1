param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot),
    [string]$SessionName = "Claude Telegram"
)

$ErrorActionPreference = "Stop"

$startScript = Join-Path $PSScriptRoot "start-claude-telegram.ps1"
if (-not (Test-Path -LiteralPath $startScript)) {
    throw "Start script not found: $startScript"
}

$argumentList = @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$startScript`"",
    "-Workspace", "`"$Workspace`"",
    "-SessionName", "`"$SessionName`""
) -join " "

Start-Process powershell -ArgumentList $argumentList -WorkingDirectory $Workspace -WindowStyle Normal
Write-Host "Opened Claude Telegram session window." -ForegroundColor Green

