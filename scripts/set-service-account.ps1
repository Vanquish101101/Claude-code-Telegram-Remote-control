# set-service-account.ps1
# ASCII only - PS 5.1 reads .ps1 as ANSI without a UTF-8 BOM and Cyrillic breaks the parser.
#
# Makes ClaudeTelegramBot / ClaudeMcpHealthMonitor run as the interactive user
# instead of LocalSystem.
#
# Why: the bot shells out to claude.exe, which reads its OAuth session from
# %USERPROFILE%\.claude\.credentials.json. As LocalSystem that resolves to
# C:\Windows\System32\config\systemprofile, where no session exists, so every
# request came back "Not logged in - Please run /login". The old system ran the
# bot as a Scheduled Task under this user (LogonType: InteractiveToken), which
# is why authentication worked there.
#
# Run from an ELEVATED PowerShell window that you opened yourself. The password
# is read with -AsSecureString and handed to the service control manager through
# the CIM Change() method, so it never appears in a transcript, a file, or a
# process command line.
#
# Usage:  .\scripts\set-service-account.ps1

param(
    [string]$Account  = "$env:COMPUTERNAME\$env:USERNAME",
    [string[]]$Services = @("ClaudeTelegramBot", "ClaudeMcpHealthMonitor")
)

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Needs an elevated PowerShell (Run as administrator)." -ForegroundColor Red
    exit 1
}

Write-Host "Account: $Account" -ForegroundColor Cyan
$secure = Read-Host "Windows password for this account" -AsSecureString
$bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

    # Windows refuses to log a service on with a blank password, and it refuses
    # silently: Change() succeeds, then the service will not start. Stop here
    # rather than leaving the services broken.
    if ([string]::IsNullOrEmpty($plain)) {
        Write-Host "`nEmpty password - Windows will not run a service under an account" -ForegroundColor Red
        Write-Host "with no password. Nothing was changed."
        Write-Host "`nEither set a password on this account, or keep the current setup"
        Write-Host "(LocalSystem with a profile override), which already works."
        exit 1
    }

    # --- 1. Grant "Log on as a service" -----------------------------------
    # sc.exe/CIM do not grant SeServiceLogonRight; without it the service will
    # fail to start with error 1069 (logon failure).
    Write-Host "`nGranting SeServiceLogonRight..." -ForegroundColor Cyan
    $sid = (New-Object Security.Principal.NTAccount($Account)).Translate(
        [Security.Principal.SecurityIdentifier]).Value

    $tmp = Join-Path $env:TEMP "secpol-$(Get-Random)"
    secedit /export /cfg "$tmp.inf" /areas USER_RIGHTS | Out-Null
    $inf  = Get-Content "$tmp.inf"
    $line = $inf | Where-Object { $_ -match '^SeServiceLogonRight' }

    if ($line -and $line -match [regex]::Escape($sid)) {
        Write-Host "  already granted"
    } else {
        if ($line) {
            $new = $inf -replace [regex]::Escape($line), "$line,*$sid"
        } else {
            $new = $inf -replace '(\[Privilege Rights\])', "`$1`r`nSeServiceLogonRight = *$sid"
        }
        # secedit templates must be UTF-16.
        $new | Out-File "$tmp.inf" -Encoding unicode -Force
        secedit /configure /db "$tmp.sdb" /cfg "$tmp.inf" /areas USER_RIGHTS | Out-Null
        Write-Host "  granted" -ForegroundColor Green
    }
    Remove-Item "$tmp.*" -Force -ErrorAction SilentlyContinue

    # --- 2. Point each service at the account -----------------------------
    foreach ($svc in $Services) {
        Write-Host "`n$svc" -ForegroundColor Cyan
        $s = Get-CimInstance Win32_Service -Filter "Name='$svc'" -ErrorAction SilentlyContinue
        if (-not $s) { Write-Host "  no such service" -ForegroundColor Yellow; continue }

        Write-Host "  was running as: $($s.StartName)"
        $r = Invoke-CimMethod -InputObject $s -MethodName Change -Arguments @{
            StartName     = $Account
            StartPassword = $plain
        }
        if ($r.ReturnValue -ne 0) {
            Write-Host "  FAILED, Change() returned $($r.ReturnValue)" -ForegroundColor Red
            Write-Host "  (2 = access denied, 21 = invalid parameter, 22 = invalid account)"
            continue
        }

        # Prove the account actually starts the service BEFORE dropping the
        # LocalSystem profile override - otherwise a rejected logon leaves the
        # bot with neither identity and no way to find its OAuth session.
        $started = $false
        try {
            Restart-Service -Name $svc -Force -ErrorAction Stop
            Start-Sleep -Seconds 4
            $started = (Get-Service -Name $svc).Status -eq "Running"
        } catch {
            Write-Host "  service refused to start: $($_.Exception.Message)" -ForegroundColor Red
        }

        if (-not $started) {
            Write-Host "  rolling back to LocalSystem" -ForegroundColor Yellow
            $s2 = Get-CimInstance Win32_Service -Filter "Name='$svc'"
            Invoke-CimMethod -InputObject $s2 -MethodName Change -Arguments @{
                StartName = "LocalSystem"; StartPassword = ""
            } | Out-Null
            Start-Service -Name $svc -ErrorAction SilentlyContinue
            Write-Host "  restored: $((Get-Service -Name $svc).Status)" -ForegroundColor Yellow
            continue
        }

        # Started cleanly as the user, so the override is now redundant - and
        # leaving it would be a second, silently diverging source of truth.
        $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc\Parameters"
        if (Get-ItemProperty -Path $k -Name AppEnvironmentExtra -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $k -Name AppEnvironmentExtra
            Restart-Service -Name $svc -Force
            Start-Sleep -Seconds 4
            Write-Host "  removed AppEnvironmentExtra override"
        }

        $after = Get-CimInstance Win32_Service -Filter "Name='$svc'"
        Write-Host ("  now: {0}, running as {1}" -f $after.State, $after.StartName) -ForegroundColor Green
    }
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Variable plain -ErrorAction SilentlyContinue
}

Write-Host "`nNow message the bot in Telegram. It should answer instead of 'Not logged in'." -ForegroundColor Cyan
