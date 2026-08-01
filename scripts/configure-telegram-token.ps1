param(
    [string]$AllowUserId = "1064521326",
    [ValidateSet("pairing", "allowlist", "disabled")]
    [string]$DmPolicy = "allowlist"
)

$ErrorActionPreference = "Stop"

$telegramStateDir = Join-Path $env:USERPROFILE ".claude\channels\telegram"
$telegramEnvPath = Join-Path $telegramStateDir ".env"
$accessPath = Join-Path $telegramStateDir "access.json"

New-Item -ItemType Directory -Path $telegramStateDir -Force | Out-Null

Write-Host "Claude Telegram state: $telegramStateDir" -ForegroundColor Cyan
Write-Host "Paste Telegram Bot Token from @BotFather. It will be stored only in ~/.claude/channels/telegram/.env." -ForegroundColor Cyan

$secureToken = Read-Host "Telegram Bot Token" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
$token = $null

try {
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr).Trim()
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Telegram token is empty."
    }

    if ($token -notmatch "^\d+:[A-Za-z0-9_-]{20,}$") {
        Write-Warning "Token does not look like a standard Telegram bot token. Saving anyway."
    }

    if (Test-Path -LiteralPath $telegramEnvPath) {
        $backupPath = "$telegramEnvPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $telegramEnvPath -Destination $backupPath -Force
        Write-Host "Existing .env backed up to: $backupPath" -ForegroundColor Yellow
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($telegramEnvPath, "TELEGRAM_BOT_TOKEN=$token", $utf8NoBom)
    Write-Host "Telegram token saved." -ForegroundColor Green

    if (Test-Path -LiteralPath $accessPath) {
        try {
            $access = Get-Content -LiteralPath $accessPath -Raw | ConvertFrom-Json
        } catch {
            $badPath = "$accessPath.bad-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Move-Item -LiteralPath $accessPath -Destination $badPath -Force
            Write-Warning "Invalid access.json moved to: $badPath"
            $access = $null
        }
    }

    if (-not $access) {
        $access = [pscustomobject]@{
            dmPolicy = $DmPolicy
            allowFrom = @()
            groups = [pscustomobject]@{}
            pending = [pscustomobject]@{}
        }
    }

    $access.dmPolicy = $DmPolicy

    if (-not ($access.PSObject.Properties.Name -contains "allowFrom") -or -not $access.allowFrom) {
        $access | Add-Member -NotePropertyName "allowFrom" -NotePropertyValue @() -Force
    }

    if (-not [string]::IsNullOrWhiteSpace($AllowUserId)) {
        $allowList = @($access.allowFrom | ForEach-Object { [string]$_ })
        if ($allowList -notcontains [string]$AllowUserId) {
            $allowList += [string]$AllowUserId
        }
        $access.allowFrom = $allowList
    }

    if (-not ($access.PSObject.Properties.Name -contains "groups")) {
        $access | Add-Member -NotePropertyName "groups" -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    if (-not ($access.PSObject.Properties.Name -contains "pending")) {
        $access | Add-Member -NotePropertyName "pending" -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $access | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $accessPath -Encoding utf8
    Write-Host "Access control saved: dmPolicy=$DmPolicy, allowFrom=$($access.allowFrom -join ', ')" -ForegroundColor Green
}
finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    $token = $null
}

Write-Host ""
Write-Host "Next step:" -ForegroundColor Cyan
Write-Host "  .\scripts\start-claude-telegram.ps1"
