$botExe  = "C:\Users\AI Developments\AppData\Local\hermes\hermes-agent\venv\Scripts\claude-telegram-bot.exe"
$config  = "C:\Users\AI Developments\Documents\Working environment\Claude code + Telegram [Remote control]\.claude-telegram\.env"
$logDir  = "C:\Users\AI Developments\AppData\Local\foresight-bots\logs\claude-telegram"
$logFile = "$logDir\restart.log"
$stdOut  = "$logDir\bot-stdout.log"
$stdErr  = "$logDir\bot-stderr.log"

# Persistent log dir (NOT %TEMP% вЂ” survives reboot/cleanup)
$null = New-Item -ItemType Directory -Force $logDir -ErrorAction SilentlyContinue

function Log($m) { $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Add-Content -LiteralPath $logFile "$ts  $m" }
function Get-BotProcs { @(Get-CimInstance Win32_Process -Filter "Name='claude-telegram-bot.exe'" -ErrorAction SilentlyContinue) }

# --- Singleton guard: kill stray bots at startup so only one polls Telegram (prevents getUpdates 409 conflict) ---
$stray = Get-BotProcs
if ($stray.Count -gt 0) {
    Log "[CLEANUP] Found $($stray.Count) existing bot process(es) at startup. Terminating to avoid 409 conflict."
    foreach ($pr in $stray) { try { Stop-Process -Id $pr.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
    Start-Sleep -Seconds 3
}

$delay    = 10
$maxDelay = 300

while ($true) {
    # If a bot is already running (e.g. relaunched by the watchdog), do not spawn a duplicate
    if ((Get-BotProcs).Count -gt 0) {
        Start-Sleep -Seconds 30
        continue
    }
    if (-not (Test-Path -LiteralPath $botExe)) {
        Log "[FATAL] Bot exe not found: $botExe. Retry in ${maxDelay}s."
        Start-Sleep -Seconds $maxDelay
        continue
    }

    Log "[START] Launching claude-telegram-bot"
    $started = Get-Date
    try {
        $p = Start-Process -FilePath $botExe `
            -ArgumentList "--config-file `"$config`"" `
            -RedirectStandardOutput $stdOut `
            -RedirectStandardError  $stdErr `
            -NoNewWindow -PassThru
        $p.WaitForExit()
        $exitCode = $p.ExitCode
    } catch {
        Log "[ERR] Launch failed: $_"
        $exitCode = -1
    }

    # Exponential backoff on crash-loops; reset if the bot ran healthy for a while
    $ranSec = [int]((Get-Date) - $started).TotalSeconds
    if ($ranSec -ge 60) {
        $delay = 10
        Log "[EXIT] Bot exited (code $exitCode) after ${ranSec}s. Restarting in ${delay}s..."
    } else {
        Log "[EXIT] Bot exited (code $exitCode) after ${ranSec}s (crash-loop). Backoff ${delay}s..."
        $delay = [Math]::Min($delay * 2, $maxDelay)
    }
    Start-Sleep -Seconds $delay
}
