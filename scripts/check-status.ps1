param(
    [switch]$ProbeMcp
)

$ErrorActionPreference = "Continue"

$pluginName = "telegram@claude-plugins-official"
$channelFlag = "plugin:$pluginName"
$claudeRoot = Join-Path $env:USERPROFILE ".claude"
$telegramStateDir = Join-Path $claudeRoot "channels\telegram"
$telegramEnvPath = Join-Path $telegramStateDir ".env"
$accessPath = Join-Path $telegramStateDir "access.json"
$settingsPath = Join-Path $claudeRoot "settings.json"

function Write-Section([string]$Text) {
    Write-Host ""
    Write-Host "-- $Text --" -ForegroundColor Yellow
}

function Write-Ok([string]$Text) {
    Write-Host "[OK]   $Text" -ForegroundColor Green
}

function Write-Warn([string]$Text) {
    Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Write-Bad([string]$Text) {
    Write-Host "[BAD]  $Text" -ForegroundColor Red
}

Write-Host "=== Claude Code + Telegram: status ===" -ForegroundColor Cyan

Write-Section "Commands"
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    Write-Ok "claude: $($claudeCmd.Source)"
    try {
        $claudeVersion = (& $claudeCmd.Source --version 2>&1 | Select-Object -First 1)
        Write-Host "       version: $claudeVersion"
    } catch {
        Write-Warn "Could not read claude version: $_"
    }
} else {
    Write-Bad "claude command not found"
}

$bunCmd = Get-Command bun -ErrorAction SilentlyContinue
if ($bunCmd) {
    Write-Ok "bun: $($bunCmd.Source)"
    try {
        $bunVersion = (& $bunCmd.Source --version 2>&1 | Select-Object -First 1)
        Write-Host "       version: $bunVersion"
    } catch {
        Write-Warn "Could not read bun version: $_"
    }
} else {
    Write-Bad "bun command not found. Telegram plugin needs Bun."
}

Write-Section "Claude Telegram plugin"
if ($claudeCmd) {
    try {
        $plugins = & $claudeCmd.Source plugin list 2>&1
        $telegramLine = $plugins | Select-String -Pattern "telegram@claude-plugins-official" -Context 0,3
        if ($telegramLine) {
            Write-Ok "$pluginName is installed"
            $telegramLine | ForEach-Object { $_.ToString() } | Write-Host
        } else {
            Write-Bad "$pluginName is not installed"
            Write-Host "       Install inside Claude Code: /plugin install $pluginName"
        }
    } catch {
        Write-Warn "Could not query plugin list: $_"
    }
}

Write-Section "Claude settings"
if (Test-Path -LiteralPath $settingsPath) {
    try {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $enabledProp = $settings.enabledPlugins.PSObject.Properties[$pluginName]
        if ($enabledProp -and [bool]$enabledProp.Value) {
            Write-Ok "settings.json enables $pluginName"
        } else {
            Write-Warn "settings.json does not show $pluginName as enabled"
        }
    } catch {
        Write-Warn "Could not parse settings.json: $_"
    }
} else {
    Write-Warn "settings.json not found: $settingsPath"
}

Write-Section "Telegram token"
if (Test-Path -LiteralPath $telegramEnvPath) {
    $envText = Get-Content -LiteralPath $telegramEnvPath -Raw
    $tokenMatch = [regex]::Match($envText, "(?m)^\s*TELEGRAM_BOT_TOKEN\s*=\s*(.+?)\s*$")
    if ($tokenMatch.Success -and -not [string]::IsNullOrWhiteSpace($tokenMatch.Groups[1].Value)) {
        $tokenLength = $tokenMatch.Groups[1].Value.Trim().Length
        Write-Ok "token is set in $telegramEnvPath (length: $tokenLength chars)"
    } else {
        Write-Bad "TELEGRAM_BOT_TOKEN is missing or empty in $telegramEnvPath"
        Write-Host "       Run: .\scripts\configure-telegram-token.ps1"
    }
} else {
    Write-Bad "Telegram .env not found: $telegramEnvPath"
    Write-Host "       Run: .\scripts\configure-telegram-token.ps1"
}

Write-Section "Access control"
if (Test-Path -LiteralPath $accessPath) {
    try {
        $access = Get-Content -LiteralPath $accessPath -Raw | ConvertFrom-Json
        Write-Ok "access.json found"
        Write-Host "       dmPolicy: $($access.dmPolicy)"
        $allowed = @($access.allowFrom)
        if ($allowed.Count -gt 0) {
            Write-Host "       allowFrom: $($allowed -join ', ')"
        } else {
            Write-Warn "allowFrom is empty"
        }
        $groups = @()
        if ($access.groups) {
            $groups = @($access.groups.PSObject.Properties | ForEach-Object { $_.Name } | Where-Object { $_ })
        }
        if ($groups.Count -gt 0) {
            Write-Host "       groups: $($groups -join ', ')"
        } else {
            Write-Host "       groups: none"
        }
    } catch {
        Write-Bad "Could not parse access.json: $_"
    }
} else {
    Write-Warn "access.json not found: $accessPath"
}

Write-Section "Running processes"
$allProcesses = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue

$officialSessions = $allProcesses |
    Where-Object {
        $_.Name -eq "claude.exe" -and $_.CommandLine -match [regex]::Escape($channelFlag)
    } |
    Select-Object ProcessId, Name, CommandLine

if ($officialSessions) {
    Write-Ok "Active Claude Code Telegram channel session(s) found"
    $officialSessions | Format-Table -AutoSize
} else {
    Write-Warn "No active Claude Code Telegram channel session found"
    Write-Host "       Start: .\scripts\start-claude-telegram.ps1"
}

$legacyProcesses = $allProcesses |
    Where-Object {
        $_.CommandLine -match "claude-telegram-bot" -or
        $_.CommandLine -match "claude-channel-telegram|claude-plugins-official.*telegram"
    } |
    Where-Object {
        -not ($_.Name -eq "claude.exe" -and $_.CommandLine -match [regex]::Escape($channelFlag))
    } |
    Select-Object ProcessId, Name, CommandLine

if ($legacyProcesses) {
    Write-Warn "Other Telegram bridge process(es) are running"
    $legacyProcesses | Format-Table -AutoSize
}

Write-Section "Scheduled tasks"
$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -match "Claude|Telegram|MCP|Hermes|OpenClaw" } |
    Select-Object TaskName, State, TaskPath

if ($tasks) {
    $tasks | Format-Table -AutoSize
} else {
    Write-Host "No related scheduled tasks found."
}

if ($ProbeMcp -and $claudeCmd) {
    Write-Section "MCP probe"
    try {
        & $claudeCmd.Source mcp list
    } catch {
        Write-Warn "MCP probe failed: $_"
    }
}

Write-Host ""
Write-Host "=== Check complete ===" -ForegroundColor Cyan
