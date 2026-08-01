param(
  [string]$Source = "C:\Users\Unknown\Documents\Project settings\API Keys.txt",
  [string]$HermesEnvPath = "",
  [switch]$Overwrite,
  [switch]$ConfigureOpenClawTelegram,
  [switch]$ConfigureClaudeTelegram
)

$ErrorActionPreference = "Stop"

function Test-UsableSecret {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) { return $false }

  $v = $Value.Trim().Trim('"').Trim("'").Trim().TrimEnd(",")
  if ($v.Length -lt 6) { return $false }
  if ($v -match '(?i)(your_|example|placeholder|changeme|insert|paste|xxx|redacted|\.\.\.|<|>)') {
    return $false
  }

  return $true
}

function Normalize-Secret {
  param([string]$Value)
  return $Value.Trim().Trim('"').Trim("'").Trim().TrimEnd(",")
}

function Add-Candidate {
  param(
    [hashtable]$Candidates,
    [string]$Name,
    [string]$Value,
    [string]$SourceLabel
  )

  if (-not (Test-UsableSecret $Value)) { return }
  if ($Candidates.ContainsKey($Name)) { return }

  $normalized = Normalize-Secret $Value
  $Candidates[$Name] = [ordered]@{
    value = $normalized
    source = $SourceLabel
    chars = $normalized.Length
  }
}

function Find-NamedValue {
  param(
    [string]$Text,
    [string]$Name
  )

  $escaped = [regex]::Escape($Name)
  $patterns = @(
    "(?im)^\s*[""']?$escaped[""']?\s*[:=]\s*[""']?([^""',\r\n#]+)",
    "(?im)\b$escaped\b\s*[:=]\s*[""']?([^""',\r\n#]+)"
  )

  foreach ($pattern in $patterns) {
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
      return (Normalize-Secret $match.Groups[1].Value)
    }
  }

  return $null
}

function Update-DotEnv {
  param(
    [string]$Path,
    [hashtable]$Values,
    [switch]$OverwriteExisting
  )

  $result = @{}
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }

  if (Test-Path -LiteralPath $Path) {
    $backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    $lines = [System.Collections.Generic.List[string]]::new()
    [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8) | ForEach-Object { [void]$lines.Add($_) }
  } else {
    $lines = [System.Collections.Generic.List[string]]::new()
  }

  foreach ($name in $Values.Keys) {
    $value = $Values[$name].value
    $lineIndex = -1
    $existingValue = $null

    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match "^\s*$([regex]::Escape($name))\s*=") {
        $lineIndex = $i
        $existingValue = ($lines[$i] -replace "^\s*$([regex]::Escape($name))\s*=", "")
        break
      }
    }

    if ($lineIndex -ge 0) {
      if ((-not $OverwriteExisting) -and (Test-UsableSecret $existingValue)) {
        $result[$name] = "skipped-existing"
        continue
      }

      $lines[$lineIndex] = "$name=$value"
      $result[$name] = "updated"
      continue
    }

    if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
      [void]$lines.Add("")
    }
    [void]$lines.Add("# Imported from Project settings on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$lines.Add("$name=$value")
    $result[$name] = "added"
  }

  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllLines($Path, $lines, $utf8NoBom)
  return $result
}

if (-not (Test-Path -LiteralPath $Source)) {
  throw "Source file not found: $Source"
}

$text = [IO.File]::ReadAllText($Source, [Text.Encoding]::UTF8)
$lines = [IO.File]::ReadAllLines($Source, [Text.Encoding]::UTF8)
$candidates = @{}

Add-Candidate $candidates "TELEGRAM_BOT_TOKEN" ([regex]::Match($text, '\b\d{6,12}:[A-Za-z0-9_-]{30,}\b').Value) "telegram-token-pattern"
Add-Candidate $candidates "OPENAI_API_KEY" (Find-NamedValue $text "OPENAI_API_KEY") "OPENAI_API_KEY assignment"
Add-Candidate $candidates "OPENAI_API_KEY" ([regex]::Match($text, '\bsk-[A-Za-z0-9_-]{20,}\b').Value) "openai-key-pattern"
Add-Candidate $candidates "DEEPSEEK_API_KEY" (Find-NamedValue $text "DEEPSEEK_API_KEY") "DEEPSEEK_API_KEY assignment"
Add-Candidate $candidates "DEEPSEEK_API_KEY" ([regex]::Match($text, '(?is)(deepseek|deep seek|deepseek v4).*?\b(sk-[A-Za-z0-9_-]{20,})\b').Groups[2].Value) "deepseek-section-pattern"
Add-Candidate $candidates "GITHUB_TOKEN" (Find-NamedValue $text "GITHUB_TOKEN") "GITHUB_TOKEN assignment"
Add-Candidate $candidates "GITHUB_TOKEN" ([regex]::Match($text, '\b(?:github_pat_[A-Za-z0-9_]+|ghp_[A-Za-z0-9_]{20,}|gho_[A-Za-z0-9_]{20,})\b').Value) "github-token-pattern"
Add-Candidate $candidates "APIFY_TOKEN" (Find-NamedValue $text "APIFY_TOKEN") "APIFY_TOKEN assignment"
Add-Candidate $candidates "APIFY_TOKEN" ([regex]::Match($text, '\bapify_api_[A-Za-z0-9_-]{20,}\b').Value) "apify-token-pattern"
Add-Candidate $candidates "FIRECRAWL_API_KEY" (Find-NamedValue $text "FIRECRAWL_API_KEY") "FIRECRAWL_API_KEY assignment"
Add-Candidate $candidates "FIRECRAWL_API_KEY" ([regex]::Match($text, '\bfc-[A-Za-z0-9_-]{8,}\b').Value) "firecrawl-key-pattern"
Add-Candidate $candidates "CHROMA_HOST" (Find-NamedValue $text "CHROMA_HOST") "CHROMA_HOST assignment"
Add-Candidate $candidates "CHROMA_API_KEY" (Find-NamedValue $text "CHROMA_API_KEY") "CHROMA_API_KEY assignment"
Add-Candidate $candidates "CHROMA_TENANT" (Find-NamedValue $text "CHROMA_TENANT") "CHROMA_TENANT assignment"
Add-Candidate $candidates "CHROMA_DATABASE" (Find-NamedValue $text "CHROMA_DATABASE") "CHROMA_DATABASE assignment"
Add-Candidate $candidates "SUPABASE_URL" ([regex]::Match($text, 'https://[a-z0-9-]+\.supabase\.co').Value) "supabase-url-pattern"
Add-Candidate $candidates "SUPABASE_SECRET_KEY" ([regex]::Match($text, '\bsb_secret_[A-Za-z0-9_-]{20,}\b').Value) "supabase-secret-key-pattern"
Add-Candidate $candidates "SMITHERY_API_KEY" (Find-NamedValue $text "SMITHERY_API_KEY") "SMITHERY_API_KEY assignment"

for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  $jwt = [regex]::Match($line, '\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{20,}\b')
  if (-not $jwt.Success) { continue }

  $start = [Math]::Max(0, $i - 8)
  $window = ($lines[$start..$i] -join "`n").ToLowerInvariant()
  if ($window -match 'anon|public') {
    Add-Candidate $candidates "SUPABASE_ANON_KEY" $jwt.Value "supabase-anon-section"
  } elseif ($window -match 'service') {
    Add-Candidate $candidates "SUPABASE_SERVICE_ROLE_KEY" $jwt.Value "supabase-service-section"
  }
}

if ([string]::IsNullOrWhiteSpace($HermesEnvPath)) {
  try {
    $HermesEnvPath = (& hermes config env-path 2>$null | Select-Object -First 1).Trim()
  } catch {
    $HermesEnvPath = "C:\Users\Unknown\AppData\Local\hermes\.env"
  }
}

$envActions = Update-DotEnv -Path $HermesEnvPath -Values $candidates -OverwriteExisting:$Overwrite

$openClawEnvAction = "not-found"
if ($candidates.ContainsKey("DEEPSEEK_API_KEY")) {
  $openClawEnvPath = "C:\Users\Unknown\.openclaw\.env"
  $openClawEnvAction = (Update-DotEnv -Path $openClawEnvPath -Values @{ "DEEPSEEK_API_KEY" = $candidates["DEEPSEEK_API_KEY"] } -OverwriteExisting:$Overwrite)["DEEPSEEK_API_KEY"]
}

function Ensure-ObjectProperty {
  param(
    [Parameter(Mandatory = $true)]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue ([pscustomobject]@{})
  }

  return $Object.$Name
}

function Update-OpenClawJson {
  param(
    [string]$TelegramTokenFile,
    [bool]$SetDeepSeekModel
  )

  $configPath = "C:\Users\Unknown\.openclaw\openclaw.json"
  if (-not (Test-Path -LiteralPath $configPath)) {
    return "skipped-openclaw-config-not-found"
  }

  $backup = "$configPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  Copy-Item -LiteralPath $configPath -Destination $backup -Force
  $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json

  if ($TelegramTokenFile) {
    $plugins = Ensure-ObjectProperty $config "plugins"
    $pluginEntries = Ensure-ObjectProperty $plugins "entries"
    if ($pluginEntries.PSObject.Properties.Name -contains "telegram") {
      $pluginEntries.telegram.enabled = $true
    } else {
      $pluginEntries | Add-Member -NotePropertyName "telegram" -NotePropertyValue ([pscustomobject]@{ enabled = $true })
    }

    $channels = Ensure-ObjectProperty $config "channels"
    if ($channels.PSObject.Properties.Name -contains "telegram") {
      $channels.telegram.enabled = $true
      if ($channels.telegram.PSObject.Properties.Name -contains "tokenFile") {
        $channels.telegram.tokenFile = $TelegramTokenFile
      } else {
        $channels.telegram | Add-Member -NotePropertyName "tokenFile" -NotePropertyValue $TelegramTokenFile
      }
      if ($channels.telegram.PSObject.Properties.Name -contains "token") {
        $channels.telegram.PSObject.Properties.Remove("token")
      }
    } else {
      $channels | Add-Member -NotePropertyName "telegram" -NotePropertyValue ([pscustomobject]@{
        enabled = $true
        tokenFile = $TelegramTokenFile
      })
    }
  }

  if ($SetDeepSeekModel) {
    $agents = Ensure-ObjectProperty $config "agents"
    $defaults = Ensure-ObjectProperty $agents "defaults"
    $model = Ensure-ObjectProperty $defaults "model"
    if ($model.PSObject.Properties.Name -contains "primary") {
      $model.primary = "deepseek/deepseek-v4-pro"
    } else {
      $model | Add-Member -NotePropertyName "primary" -NotePropertyValue "deepseek/deepseek-v4-pro"
    }
    $models = Ensure-ObjectProperty $defaults "models"
    if (-not ($models.PSObject.Properties.Name -contains "deepseek/deepseek-v4-pro")) {
      $models | Add-Member -NotePropertyName "deepseek/deepseek-v4-pro" -NotePropertyValue ([pscustomobject]@{})
    }

    $auth = Ensure-ObjectProperty $config "auth"
    $profiles = Ensure-ObjectProperty $auth "profiles"
    if ($profiles.PSObject.Properties.Name -contains "deepseek:manual") {
      $profiles.'deepseek:manual' = [pscustomobject]@{ provider = "deepseek"; mode = "api_key" }
    } else {
      $profiles | Add-Member -NotePropertyName "deepseek:manual" -NotePropertyValue ([pscustomobject]@{ provider = "deepseek"; mode = "api_key" })
    }
  }

  $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding UTF8
  return "updated"
}

$claudeTelegramAction = "not-requested"
if ($ConfigureClaudeTelegram) {
  $claudeTelegramToken = Find-NamedValue $text "CLAUDE_TELEGRAM_BOT_TOKEN"
  $claudeTelegramSource = "CLAUDE_TELEGRAM_BOT_TOKEN assignment"

  if (-not (Test-UsableSecret $claudeTelegramToken)) {
    $claudeTelegramToken = Find-NamedValue $text "CLAUDE_CODE_TELEGRAM_BOT_TOKEN"
    $claudeTelegramSource = "CLAUDE_CODE_TELEGRAM_BOT_TOKEN assignment"
  }

  if (-not (Test-UsableSecret $claudeTelegramToken) -and $candidates.ContainsKey("TELEGRAM_BOT_TOKEN")) {
    $claudeTelegramToken = $candidates["TELEGRAM_BOT_TOKEN"].value
    $claudeTelegramSource = $candidates["TELEGRAM_BOT_TOKEN"].source
  }

  if (Test-UsableSecret $claudeTelegramToken) {
    $normalizedClaudeTelegramToken = Normalize-Secret $claudeTelegramToken
    $claudeTelegramDir = Join-Path $env:USERPROFILE ".claude\channels\telegram"
    $claudeTelegramEnvPath = Join-Path $claudeTelegramDir ".env"

    $claudeTelegramValue = @{
      "TELEGRAM_BOT_TOKEN" = [ordered]@{
        value = $normalizedClaudeTelegramToken
        source = $claudeTelegramSource
        chars = $normalizedClaudeTelegramToken.Length
      }
    }

    $claudeTelegramAction = (Update-DotEnv -Path $claudeTelegramEnvPath -Values $claudeTelegramValue -OverwriteExisting:$Overwrite)["TELEGRAM_BOT_TOKEN"]
    try {
      $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      icacls $claudeTelegramDir /inheritance:r /grant:r "${user}:(OI)(CI)F" | Out-Null
      icacls $claudeTelegramEnvPath /inheritance:r /grant:r "${user}:F" | Out-Null
    } catch {}
  } else {
    $claudeTelegramAction = "skipped-telegram-token-not-found"
  }
}

$openClawAction = "not-requested"
if ($ConfigureOpenClawTelegram) {
  if ($candidates.ContainsKey("TELEGRAM_BOT_TOKEN")) {
    $openClawSecretDir = "C:\Users\Unknown\.openclaw\secrets"
    New-Item -ItemType Directory -Path $openClawSecretDir -Force | Out-Null
    $telegramTokenFile = Join-Path $openClawSecretDir "telegram-bot-token.txt"
    Set-Content -LiteralPath $telegramTokenFile -Value $candidates["TELEGRAM_BOT_TOKEN"].value -NoNewline -Encoding ASCII
    try {
      $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      icacls $openClawSecretDir /inheritance:r /grant:r "${user}:(OI)(CI)F" | Out-Null
      icacls $telegramTokenFile /inheritance:r /grant:r "${user}:F" | Out-Null
    } catch {}
    $openClawAction = Update-OpenClawJson -TelegramTokenFile $telegramTokenFile -SetDeepSeekModel:$candidates.ContainsKey("DEEPSEEK_API_KEY")
  } else {
    $openClawAction = "skipped-telegram-token-not-found"
  }
} elseif ($candidates.ContainsKey("DEEPSEEK_API_KEY")) {
  [void](Update-OpenClawJson -TelegramTokenFile "" -SetDeepSeekModel:$true)
}

$reportDir = Join-Path (Get-Location) ".secrets"
if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir | Out-Null
}

$report = [ordered]@{
  generatedAt = (Get-Date).ToString("s")
  source = $Source
  hermesEnvPath = $HermesEnvPath
  overwrite = [bool]$Overwrite
  openClawTelegram = $openClawAction
  claudeTelegram = $claudeTelegramAction
  openClawDeepSeekEnv = $openClawEnvAction
  imported = @(
    foreach ($name in ($candidates.Keys | Sort-Object)) {
      [ordered]@{
        name = $name
        chars = $candidates[$name].chars
        source = $candidates[$name].source
        hermesEnvAction = $envActions[$name]
      }
    }
  )
}

$reportPath = Join-Path $reportDir "project-settings-import-report.json"
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host "Project settings import complete." -ForegroundColor Green
Write-Host "Source: $Source"
Write-Host "Hermes env: $HermesEnvPath"
Write-Host "OpenClaw Telegram: $openClawAction"
Write-Host "Claude Telegram: $claudeTelegramAction"
Write-Host "OpenClaw DeepSeek env: $openClawEnvAction"
Write-Host "Report: $reportPath"
Write-Host ""
Write-Host "Imported names, without values:" -ForegroundColor Cyan
foreach ($name in ($candidates.Keys | Sort-Object)) {
  Write-Host ("- {0}: {1}" -f $name, $envActions[$name])
}
