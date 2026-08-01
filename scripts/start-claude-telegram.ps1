param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot),
    [string]$SessionName = "Claude Telegram",
    [string]$Model = "",
    [ValidateSet("default", "acceptEdits", "auto", "bypassPermissions", "dontAsk", "plan")]
    [string]$PermissionMode = "",
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"

$pluginName = "telegram@claude-plugins-official"
$channelFlag = "plugin:$pluginName"
$telegramEnvPath = Join-Path $env:USERPROFILE ".claude\channels\telegram\.env"
$accessPath = Join-Path $env:USERPROFILE ".claude\channels\telegram\access.json"

$claudeExe = (Get-Command claude -ErrorAction Stop).Source

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    throw "Bun is not installed or not in PATH. The Claude Telegram plugin needs Bun."
}

if (-not (Test-Path -LiteralPath $telegramEnvPath)) {
    Write-Warning "Telegram token file not found: $telegramEnvPath"
    Write-Warning "Run .\scripts\configure-telegram-token.ps1 before starting the channel."
}

if (-not (Test-Path -LiteralPath $accessPath)) {
    Write-Warning "Access file not found: $accessPath"
}

if (-not (Test-Path -LiteralPath $Workspace)) {
    throw "Workspace does not exist: $Workspace"
}

$argsList = @(
    "--channels", $channelFlag,
    "--name", $SessionName
)

if (-not [string]::IsNullOrWhiteSpace($Model)) {
    $argsList += @("--model", $Model)
}

if (-not [string]::IsNullOrWhiteSpace($PermissionMode)) {
    $argsList += @("--permission-mode", $PermissionMode)
}

if ($ExtraArgs.Count -gt 0) {
    $argsList += $ExtraArgs
}

Write-Host "Starting Claude Code with Telegram channel..." -ForegroundColor Cyan
Write-Host "Workspace: $Workspace"
Write-Host "Command: claude $($argsList -join ' ')"
Write-Host "Stop with Ctrl+C when you want to disconnect Telegram." -ForegroundColor Yellow
Write-Host ""

Push-Location $Workspace
try {
    & $claudeExe @argsList
}
finally {
    Pop-Location
}

