# MCP Health Monitor + Bot Watchdog
# Checks MCP servers and bot health every 25 seconds
# Sends Telegram notifications for state changes

$legacyEnvPath = "C:\Users\AI Developments\Documents\Working environment\Claude code + Telegram [Remote control]\.claude-telegram\.env"
$officialEnvPath = "$env:USERPROFILE\.claude\channels\telegram\.env"
$chatId        = "1064521326"
$botServiceName = "ClaudeTelegramBot"
$checkInterval = 25
$logFile       = "C:\Users\AI Developments\AppData\Local\Temp\mcp-monitor\monitor.log"
$claudeExe     = "C:\Users\AI Developments\.local\bin\claude.exe"

# Servers to monitor (plugin is always down - exclude it)
$monitoredServers = @("supabase", "smithery", "notion")

# --- Helpers ---

function Write-Log($msg) {
    $null = New-Item -ItemType Directory -Force (Split-Path $logFile) -EA SilentlyContinue
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $logFile "$ts  $msg"
}

function Get-EnvValue($path, $name) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $line = Get-Content -LiteralPath $path -ErrorAction SilentlyContinue |
        Where-Object { $_ -match "^\s*$([regex]::Escape($name))\s*=" } |
        Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace "^\s*$([regex]::Escape($name))\s*=\s*", "").Trim()
}

function Get-TelegramBotToken {
    $token = Get-EnvValue $legacyEnvPath "TELEGRAM_BOT_TOKEN"
    if (-not [string]::IsNullOrWhiteSpace($token)) { return $token }

    $token = Get-EnvValue $officialEnvPath "TELEGRAM_BOT_TOKEN"
    if (-not [string]::IsNullOrWhiteSpace($token)) { return $token }

    return $env:TELEGRAM_BOT_TOKEN
}

function Send-TG($text) {
    try {
        $botToken = Get-TelegramBotToken
        if ([string]::IsNullOrWhiteSpace($botToken)) {
            Write-Log "[TG_ERR] TELEGRAM_BOT_TOKEN is not configured"
            return
        }
        $body = @{ chat_id = $chatId; text = $text }
        Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Body $body -ErrorAction Stop | Out-Null
    } catch {
        Write-Log "[TG_ERR] Failed to send message: $_"
    }
}

function Get-BotProcess {
    return Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*claude-telegram-bot*" }
}

function Test-BotAlive {
    $svc = Get-Service -Name $botServiceName -ErrorAction SilentlyContinue
    $svcRunning = $svc -and $svc.Status -eq "Running"
    $procRunning = $null -ne (Get-BotProcess)
    return $svcRunning -and $procRunning
}

function Restart-Bot {
    # NSSM already restarts the process on crash (AppExit Restart); this is a manual
    # nudge for cases where the service is up but the bot is wedged/unresponsive.
    Write-Log "[ACTION] Restarting bot service..."
    Restart-Service -Name $botServiceName -Force -EA SilentlyContinue
    Start-Sleep -Seconds 8
    return (Test-BotAlive)
}

function Get-MCPHealth {
    $results = @{}
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $claudeExe
        $psi.Arguments = "mcp list"
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        $raw = $stdout + $stderr
        foreach ($line in ($raw -split "`n")) {
            if ($line -match "^\s*([\w\-]+)\s*:.*?(Connected|Failed to connect|Failed)") {
                $name = $Matches[1]
                $up   = $Matches[2] -eq "Connected"
                $results[$name] = $up
            }
        }
    } catch { }
    return $results
}

# --- Init ---

Write-Log "[INIT] MCP Health Monitor started (interval: ${checkInterval}s)"
Send-TG "MCP monitor zapushchen. Slezhu za botom i serverami kazhd. ${checkInterval} sek."

$prevBotAlive  = $null
$prevMcpStatus = @{}
$mcpDownCount  = @{}
$botCrashCount = 0

# --- Main loop ---

while ($true) {

    # === 1. Bot watchdog ===

    $botAlive = Test-BotAlive

    if ($null -ne $prevBotAlive) {
        if ($prevBotAlive -and -not $botAlive) {
            $botCrashCount++
            Write-Log "[CRASH] Bot crashed (crash #$botCrashCount)"
            Send-TG "Bot upal (sboj #$botCrashCount). Perezapuskayu..."

            $ok = Restart-Bot
            if ($ok) {
                Send-TG "Bot perezapushchen uspeshno."
                Write-Log "[OK] Bot restarted"
                $botAlive = $true
            } else {
                Send-TG "Ne udalos perezapustit bota avtomaticheski. Prover vruchnuyu."
                Write-Log "[ERROR] Bot restart failed"
            }
        } elseif (-not $prevBotAlive -and $botAlive) {
            Write-Log "[UP] Bot is now alive"
        }
    }

    $prevBotAlive = $botAlive

    # === 2. MCP server health check ===

    $mcpStatus = Get-MCPHealth

    foreach ($server in ($mcpStatus.Keys | Where-Object { $monitoredServers -contains $_ })) {
        $isUp  = $mcpStatus[$server]
        $wasUp = $prevMcpStatus[$server]

        if (-not $mcpDownCount.ContainsKey($server)) { $mcpDownCount[$server] = 0 }

        if ($isUp -eq $false) {
            $mcpDownCount[$server]++
            $count = $mcpDownCount[$server]

            if ($wasUp -ne $false) {
                Write-Log "[MCP_DOWN] $server disconnected"
                Send-TG "MCP server '$server' nedostupen. Ishchu podklyucheniye..."
            } elseif ($count % 4 -eq 0) {
                $mins = [math]::Round($count * $checkInterval / 60, 0)
                Write-Log "[MCP_WAIT] $server still down (${mins}m)"
                Send-TG "MCP '$server' vsyo eshche nedostupen (${mins} min)."
            }

        } else {
            if ($wasUp -eq $false) {
                Write-Log "[MCP_UP] $server reconnected"
                Send-TG "MCP server '$server' vosstanovlen."
            }
            $mcpDownCount[$server] = 0
        }
    }

    $prevMcpStatus = $mcpStatus

    # === 3. Sleep ===

    Start-Sleep -Seconds $checkInterval
}
