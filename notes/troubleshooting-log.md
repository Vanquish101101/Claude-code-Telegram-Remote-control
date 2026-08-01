# Лог проблем и решений — все сессии

> Этот файл автоматически обновляется. Используется как база знаний для диагностики и ремонта всех ботов и сервисов.

---

## ГЛОБАЛЬНЫЕ ПРАВИЛА (применять ко всем проектам)

### Правило 1 — Кириллица в путях ломается в hidden PowerShell сессии
**Симптом:** Scheduled task запускается, но скрипт/процесс падает без ошибки.
**Причина:** `-WindowStyle Hidden -NonInteractive` сессия не может корректно обработать кириллицу в путях.
**Решение:**
```powershell
# Получить 8.3 короткий путь (без кириллицы)
$fso = New-Object -ComObject Scripting.FileSystemObject
$shortPath = $fso.GetFile("C:\путь\с\Кириллицей\файл").ShortPath
# Использовать $shortPath во всех скриптах scheduled tasks
```
**Примеры:** `C:\Users\Unknown\Documents\Lesson 1 (Урок 1)` → `C:\Users\Unknown\DOCUME~1\LESSON~1`

---

### Правило 2 — Лог-папка должна создаваться в начале wrapper-скрипта
**Симптом:** После перезагрузки Windows бот/сервис не запускается. В логе нет записей.
**Причина:** Папка для лога (в `%TEMP%`) не существует после перезагрузки.
**Решение:** Первая строка в каждом wrapper-скрипте:
```powershell
$null = New-Item -ItemType Directory -Force (Split-Path $logFile) -ErrorAction SilentlyContinue
```

---

### Правило 3 — Запуск exe в hidden сессии: Start-Process вместо &
**Симптом:** `& $exe args` → exit code 1 в hidden scheduled task. При ручном запуске работает.
**Причина:** Оператор `&` наследует stdin/stdout/stderr родительской hidden сессии, что вызывает crash некоторых exe.
**Решение:**
```powershell
# НЕ использовать:
& $botExe --arg value 2>&1

# ИСПОЛЬЗОВАТЬ:
$p = Start-Process -FilePath $botExe -ArgumentList "--arg value" `
    -RedirectStandardOutput $logOut -RedirectStandardError $logErr `
    -NoNewWindow -PassThru
$p.WaitForExit()
$exitCode = $p.ExitCode
```

---

### Правило 4 — Кодировка .env файлов
**Симптом:** Бот падает или ведёт себя странно после редактирования .env.
**Причина:** `Set-Content -Encoding UTF8 -NoNewline` перезаписывает кодировку. Кириллица в комментариях/значениях превращается в мусор.
**Решение:**
- Писать .env через `[System.IO.File]::WriteAllText(path, content, [System.Text.Encoding]::UTF8)`
- Комментарии в .env — только ASCII (транслит, не кириллица)
- Значения с кириллицей (DATABASE_URL и пути) — через Edit tool, не через Set-Content

---

### Правило 5 — 409 Conflict: несколько экземпляров Telegram-бота
**Симптом:** Бот падает с "Conflict: terminated by other getUpdates request".
**Причина:** Несколько экземпляров bot процесса запущены одновременно.
**Решение:**
```powershell
# 1. Убить все процессы бота
Get-WmiObject Win32_Process | Where-Object { $_.CommandLine -like "*claude-telegram*" } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
# 2. Подождать минимум 10 секунд (Telegram должен закрыть сессию)
Start-Sleep -Seconds 15
# 3. Запустить заново
Start-ScheduledTask -TaskName "Claude Code Telegram Bot"
```

---

### Правило 6 — Claude OAuth токен истекает каждые 4-8 часов
**Симптом:** Бот отвечает "❌ An unexpected error occurred" после нескольких часов работы.
**Причина:** OAuth токен в `~/.claude/.credentials.json` имеет срок жизни ~8 часов. В background-процессе нет возможности его обновить интерактивно.
**Решение:** Всегда использовать постоянный Anthropic API key в .env:
```
ANTHROPIC_API_KEY=sk-ant-api03-...
```
Постоянный ключ не истекает никогда.

---

### Правило 7 — CLAUDE_ALLOWED_TOOLS: обязательный минимум для Windows
**Симптом:** "🚫 Tool Access Blocked" на PowerShell, ToolSearch и т.д.
**Обязательный список:**
```
Read,Write,Edit,Bash,PowerShell,Glob,Grep,LS,Task,TaskOutput,MultiEdit,
NotebookRead,NotebookEdit,WebFetch,TodoRead,TodoWrite,WebSearch,ToolSearch
```
**+ MCP tools добавлять только если сервер настроен** (`claude mcp list` → √ Connected).

---

### Правило 8 — Проверка MCP серверов перед добавлением в ALLOWED_TOOLS
**Симптом:** Бот выдаёт ошибки MCP в конце каждого ответа.
**Причина:** MCP tool добавлен в CLAUDE_ALLOWED_TOOLS, но сервер не настроен.
**Диагностика:**
```powershell
claude mcp list  # Должна быть строка с "√ Connected"
```
**Решение:** Сначала настроить сервер, потом добавлять tools в список.

---

## ЖУРНАЛ ИНЦИДЕНТОВ

### 2026-06-13 — Сессия 1 (hermes, права, кириллица)

#### Инцидент 1.1: Hermes Gateway не стартует после перезагрузки
- **Статус:** РЕШЕНО
- **Причина:** Папка `C:\Users\Unknown\AppData\Local\Temp\hermes-gateway\` не существует после ребута → `Add-Content` падает
- **Fix:** Добавлено в `run-hermes-gateway-forever.ps1`:
  ```powershell
  $null = New-Item -ItemType Directory -Force (Split-Path $logFile) -ErrorAction SilentlyContinue
  ```
- **Задача:** `Hermes Gateway Wrapper` (Running при старте)

#### Инцидент 1.2: Постоянные вопросы разрешений Claude Code (3 варианта)
- **Статус:** РЕШЕНО
- **Причина:** Не был настроен `defaultMode: bypassPermissions` глобально
- **Fix:** Добавлено в `~/.claude/settings.json`:
  ```json
  "permissions": { "defaultMode": "bypassPermissions", "ask": [...git push/pull/fetch...] }
  ```

---

### 2026-06-13 — Сессия 2 (Telegram бот claude-code)

#### Инцидент 2.1: 🚫 Tool Access Blocked: ToolSearch
- **Статус:** РЕШЕНО
- **Fix:** Добавить `ToolSearch` в `CLAUDE_ALLOWED_TOOLS` в `.claude-telegram/.env`

#### Инцидент 2.2: 🚫 Tool Access Blocked: PowerShell
- **Статус:** РЕШЕНО
- **Fix:** Добавить `PowerShell` в `CLAUDE_ALLOWED_TOOLS`

#### Инцидент 2.3: 🚫 Tool Access Blocked: mcp__notion__*, mcp__smithery__*
- **Статус:** РЕШЕНО
- **Причина 1:** Tools добавлены в список но MCP серверы не настроены
- **Fix 1:** Убрать ненастроенные tools; настроить Notion MCP:
  ```powershell
  claude mcp add --scope user notion -e NOTION_API_KEY=<token> -- npx -y @notionhq/notion-mcp-server
  ```
- **Notion API key:** `<redacted>`

#### Инцидент 2.4: .env файл повреждён (кириллица → мусор)
- **Статус:** РЕШЕНО
- **Причина:** `Set-Content -Encoding UTF8 -NoNewline` изменил кодировку файла
- **Симптом:** Комментарии превратились в `вЂ" РєРѕРЅС„РёРіСЃ...`
- **Fix:** Переписать файл через `[System.IO.File]::WriteAllText` или Edit tool. Комментарии — ASCII only.

#### Инцидент 2.5: Бот падает exit code 1 в hidden scheduled task
- **Статус:** РЕШЕНО
- **Причина:** Оператор `& $exe 2>&1` в hidden PowerShell сессии вызывает crash
- **Fix:** Заменить на `Start-Process ... -RedirectStandardOutput ... -RedirectStandardError ... -NoNewWindow -PassThru`

#### Инцидент 2.6: 409 Conflict — несколько экземпляров бота
- **Статус:** РЕШЕНО
- **Причина:** При отладке запускались ручные экземпляры параллельно с scheduled task
- **Fix:** Убить все процессы + ждать 15 сек + перезапустить задачу

---

## СТАТУСЫ СЕРВИСОВ (на 2026-06-13 вечер)

| Сервис | Задача | Статус | Wrapper |
|--------|--------|--------|---------|
| Claude Code Telegram Bot | `Claude Code Telegram Bot` | ✓ Running | `run-claude-telegram-forever.ps1` (Start-Process, 8.3 paths) |
| Hermes Gateway | `Hermes Gateway Wrapper` | ✓ Running | `run-hermes-gateway-forever.ps1` (mkdir fix) |
| OpenClaw Gateway | `OpenClaw Telegram Gateway` | Ready (не используется активно) | `start-openclaw-gateway.ps1` |

---

## ДИАГНОСТИКА — БЫСТРАЯ ПРОВЕРКА ВСЕХ СЕРВИСОВ

```powershell
# Статус всех задач
Get-ScheduledTask | Where-Object { $_.TaskName -match "hermes|claude|openclaw|telegram" -i } | Select-Object TaskName, State

# Логи рестартов
Get-Content "C:\Users\Unknown\AppData\Local\Temp\claude-telegram\restart.log" -Tail 10
Get-Content "C:\Users\Unknown\AppData\Local\Temp\hermes-gateway\restart.log" -Tail 10

# Статус Hermes gateway
hermes gateway status
hermes status | Select-String "Telegram|Gateway"

# MCP серверы
claude mcp list
```

---

## ВОССТАНОВЛЕНИЕ — ЕСЛИ ЧТО-ТО НЕ РАБОТАЕТ

### Claude Code Telegram Bot не отвечает:
```powershell
# 1. Убить все процессы
Get-WmiObject Win32_Process | Where-Object { $_.CommandLine -like "*claude-telegram*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
Start-Sleep -Seconds 15
# 2. Перезапустить
Stop-ScheduledTask "Claude Code Telegram Bot" -EA SilentlyContinue
Start-Sleep 3
Start-ScheduledTask "Claude Code Telegram Bot"
# 3. Проверить лог
Get-Content "C:\Users\Unknown\AppData\Local\Temp\claude-telegram\restart.log" -Tail 10
```

### Hermes Gateway не работает:
```powershell
hermes gateway status
# Если "No gateway process detected":
$h = (Get-Command hermes).Source
Start-Process $h -ArgumentList "gateway","run" -WindowStyle Hidden
Start-Sleep 5
hermes gateway status
```

---

### 2026-06-13 - Finalnoye sostoyaniye sistemy (vecher)

#### Incident 2.7: Wrapper & $exe padayet v hidden session (GLAVNAYA PRICHINA nestabilnosti)
- **Status:** RESHENO
- **Prichina:** `& $botExe 2>&1` v hidden PS session vyzyvayet crash Python exe
- **Fix:** Zamenit na `Start-Process -WindowStyle Hidden -PassThru; $p.WaitForExit()`
- **Primeneniya k:** run-claude-telegram-forever.ps1

#### Incident 2.8: Scheduled task padayet iz-za kirillitsy v puti k scriptu
- **Status:** RESHENO
- **Prichina:** `-File "...\Lesson 1 (Urok 1)\scripts\..."` - kirillitsa v puti PS1
- **Fix:** Ispolzovat 8.3 short path: C:\Users\Unknown\DOCUME~1\LESSON~1\scripts\RUN-CL~1.PS1

#### Incident 2.9: Task ne zapuskaetsya posle propuska triggera
- **Status:** RESHENO
- **Prichina:** StartWhenAvailable=False - zadacha ne startuyet esli propustila logon trigger
- **Fix:** StartWhenAvailable=True, RestartCount=10, MultipleInstances=IgnoreNew

#### Novyy komponent: MCP Health Monitor
- **Zadacha:** `Claude MCP Health Monitor` (Running)
- **Skript:** scripts\mcp-health-monitor.ps1
- **Log:** %TEMP%\mcp-monitor\monitor.log
- **Funktsii:** monitoriyt supabase/smithery/notion kazhd. 25 sek, pereezapuskayet bota pri padenii, shlyot TG uvedomleniya

#### FINALNYY STATUS (2026-06-13 ~22:45)
| Servis | State |
|--------|-------|
| Claude Code Telegram Bot | Running |
| Claude MCP Health Monitor | Running |
| Hermes Gateway Wrapper | Running (6+ ch aptyaym) |
| Supabase MCP | Connected |
| Smithery MCP | Connected |
