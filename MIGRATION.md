# MIGRATION.md — Полное руководство по переносу проекта
# Claude code + Telegram Telemost

> Создано: 2026-07-14  
> Состояние на момент создания: все сервисы Running  
> Размер папки проекта: ~0.52 МБ  
> Целевой диск: E:\  
> Целевой путь: `E:\Claude code + Telegram Telemost`

---

## СВЯЗАННЫЕ ПРОЕКТЫ (метки)

Этот проект существует в экосистеме трёх ботов. При переносе учитывать все три:

| Проект | Текущий путь | Диск E (уже перенесён?) |
|--------|-------------|------------------------|
| **Claude code + Telegram Telemost** (этот) | `C:\Users\Unknown\Documents\Projects\Claude code + Telegram Telemost` | нет |
| OpenClaw + DeepSeek v4 + Telegram | `C:\Users\Unknown\Documents\Projects\OpenClaw + DeepSeek v4 + Telegram` | ДА (`E:\OpenClaw + DeepSeek v4 + Telegram`) |
| Hermes + DeepSeek v4 + Telegram | `C:\Users\Unknown\Documents\Projects\Hermes + DeepSeek v4 + Telegram` | нет |

> ⚠️ **ВАЖНО:** `mcp-health-monitor.ps1` и `run-claude-telegram-forever.ps1` ссылаются на абсолютные пути C:\. После переноса на E:\ — обновить пути во всех скриптах и пересоздать Scheduled Tasks.

---

## СТРУКТУРА ЭТОЙ ПАПКИ

```
Claude code + Telegram Telemost\
├── .claude\                    ← настройки Claude Code для этого проекта
│   ├── settings.json           ← права, хуки
│   ├── settings.local.json
│   └── stop-hook.ps1
├── .claude-telegram\           ← LEGACY бот (активный)
│   ├── .env                    ← токен, allowed users, конфиг
│   └── bot.db                  ← SQLite база состояния (сессии пользователей)
├── .codex\
│   └── hooks.json
├── .secrets\                   ← gitignored, не коммитить
├── logs\
├── notes\
│   ├── root-folders.md
│   └── troubleshooting-log.md  ← база знаний, 8 правил диагностики
├── scripts\
│   ├── check-status.ps1        ← главная диагностика
│   ├── check-all-status.ps1
│   ├── configure-telegram-token.ps1
│   ├── mcp-health-monitor.ps1  ← watchdog MCP + бот
│   ├── run-claude-telegram-forever.ps1 ← wrapper для legacy бота
│   ├── start-claude-telegram.ps1
│   ├── stop-claude-telegram.ps1
│   └── open-claude-telegram-window.ps1
├── MIGRATION.md                ← этот файл
├── README.md
├── AGENTS.md
├── CHECKLIST.md
├── LESSON-README.md
└── session-2026-06-15.md
```

---

## ГЛОБАЛЬНЫЕ РЕСУРСЫ (вне папки проекта)

Эти ресурсы НЕ копируются вместе с папкой. Их нужно переустановить или перенести отдельно.

### 1. Claude CLI

| Что | Путь |
|-----|------|
| Бинарник | `C:\Users\Unknown\.local\bin\claude.exe` |
| Версия | `2.1.177` |
| Глобальный конфиг | `C:\Users\Unknown\.claude\settings.json` |
| MCP конфиг | `C:\Users\Unknown\.claude.json` |
| Telegram plugin токен | `C:\Users\Unknown\.claude\channels\telegram\.env` |
| Telegram access | `C:\Users\Unknown\.claude\channels\telegram\access.json` |

**Установка на новой системе:**
```powershell
# Установить Claude CLI
npm install -g @anthropic-ai/claude-code
# или скачать бинарник с claude.ai
```

**Telegram plugin:**
```powershell
claude plugin install telegram@claude-plugins-official
# Затем настроить токен:
.\scripts\configure-telegram-token.ps1
```

---

### 2. Hermes (legacy bot binary + конфиги)

| Что | Путь |
|-----|------|
| Бинарник бота | `C:\Users\Unknown\AppData\Local\hermes\hermes-agent\venv\Scripts\claude-telegram-bot.exe` |
| Конфиг Hermes | `C:\Users\Unknown\AppData\Local\hermes\config.yaml` |
| Секреты Hermes | `C:\Users\Unknown\AppData\Local\hermes\.env` |
| Логи legacy бота | `C:\Users\Unknown\AppData\Local\foresight-bots\logs\claude-telegram\` |

> 📌 **МЕТКА:** Hermes установлен как системный инструмент. При переезде на новую систему нужна переустановка Hermes + Python venv.

---

### 3. Scheduled Tasks (Windows Task Scheduler)

Все три задачи указывают на C:\ пути. После переноса — пересоздать.

| Задача | Состояние | Скрипт (8.3 путь) |
|--------|-----------|-------------------|
| Claude Code Telegram Bot | **Running** | `C:\Users\Unknown\DOCUME~1\Projects\CLAUDE~1\scripts\RUN-CL~1.PS1` |
| Claude MCP Health Monitor | **Running** | `C:\Users\Unknown\DOCUME~1\Projects\CLAUDE~1\scripts\MCP-HE~1.PS1` |
| Hermes Gateway Wrapper | **Running** | `C:\Users\Unknown\Documents\Projects\Hermes + DeepSeek v4 + Telegram\scripts\run-hermes-gateway-forever.ps1` |
| Hermes_Gateway | Disabled | — |
| OpenClaw Gateway | Disabled | — |

**Пересоздание задач после переноса на E:\:**
```powershell
# Получить 8.3 путь нового расположения
$fso = New-Object -ComObject Scripting.FileSystemObject
$shortPath = $fso.GetFile("E:\Claude code + Telegram Telemost\scripts\run-claude-telegram-forever.ps1").ShortPath

# Обновить задачу
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$shortPath`""
Set-ScheduledTask -TaskName "Claude Code Telegram Bot" -Action $action
```

---

## СОЦИАЛЬНЫЕ СЕТИ И КАНАЛЫ (метки доступа)

### Telegram

| Что | Где хранится | Статус |
|-----|-------------|--------|
| Токен legacy бота (@foresight_project_claudecode_bot) | `.claude-telegram\.env` → `TELEGRAM_BOT_TOKEN` | Активен |
| Токен official plugin | `~\.claude\channels\telegram\.env` → `TELEGRAM_BOT_TOKEN` | Активен |
| Разрешённый user ID | `.claude-telegram\.env` → `ALLOWED_USERS=1064521326` | — |
| Access policy | `~\.claude\channels\telegram\access.json` → `dmPolicy: allowlist` | — |
| allowFrom | `~\.claude\channels\telegram\access.json` → `["1064521326"]` | — |

**Проверка Telegram после переноса:**
```powershell
# 1. Запустить бота
.\scripts\start-claude-telegram.ps1
# 2. Написать боту в Telegram — должен ответить
# 3. Проверить логи
Get-Content "$env:LOCALAPPDATA\foresight-bots\logs\claude-telegram\restart.log" -Tail 20
```

> ⚠️ **409 Conflict**: Нельзя запускать два экземпляра с одним токеном. Убить старый процесс перед запуском нового.

### VK

> Доступ к VK в данном проекте не настроен (не обнаружен).

---

## MCP СЕРВЕРЫ (метки сервисов)

Все MCP серверы настроены **глобально** в:
- `C:\Users\Unknown\.claude\settings.json` (Claude Code)  
- `C:\Users\Unknown\AppData\Local\hermes\config.yaml` (Hermes)

### Облачные MCP (ключи хранятся в конфигах выше)

| Сервис | Переменная ключа | Файл конфига |
|--------|-----------------|-------------|
| Supabase | `SUPABASE_ACCESS_TOKEN` | `~\.claude\settings.json` → mcpServers.supabase |
| Apify | `APIFY_TOKEN` | `~\.claude\settings.json` → mcpServers.apify |
| Perplexity | `PERPLEXITY_API_KEY` | `~\.claude\settings.json` → mcpServers.perplexity |
| Firecrawl | `FIRECRAWL_API_KEY` | `~\.claude\settings.json` → mcpServers.firecrawl |
| OpenAI/Whisper | `OPENAI_API_KEY` | `~\.claude\settings.json` → mcpServers.whisper |
| Deepgram | `DEEPGRAM_API_KEY` | `~\.claude\settings.json` → mcpServers.deepgram |
| HuggingFace | `HUGGINGFACE_TOKEN` | `~\.claude\settings.json` → mcpServers.huggingface |
| GitHub | `GITHUB_PERSONAL_ACCESS_TOKEN` | `~\.claude\settings.json` → mcpServers.github |
| OpenRouter | `OPENROUTER_API_KEY` | `~\.claude\settings.json` + hermes config.yaml |
| Replicate | `REPLICATE_API_TOKEN` | `~\.claude\settings.json` → mcpServers.replicate |
| ElevenLabs | `ELEVENLABS_API_KEY` | `~\.claude\settings.json` → mcpServers.elevenlabs |
| Vercel | `API_KEY` | `~\.claude\settings.json` → mcpServers.vercel |
| LangSmith | `LANGSMITH_API_KEY` | `~\.claude\settings.json` → mcpServers.langsmith |
| Runway | `RUNWAY_API_KEY` | `~\.claude\settings.json` → mcpServers.runway |
| Helicone | `HELICONE_API_KEY` | `~\.claude\settings.json` + hermes config.yaml |
| Notion | `NOTION_TOKEN` | `~\.claude\settings.json` → mcpServers.notion |
| Gemini | `GOOGLE_API_KEY` / `GEMINI_API_KEY` | `~\.claude\settings.json` → mcpServers.gemini |
| Groq | `GROQ_API_KEY` | `~\.claude\settings.json` → mcpServers.groq |
| Pinecone | `PINECONE_API_KEY` | hermes config.yaml → mcp_servers.pinecone |
| Qdrant Cloud | `QDRANT_API_KEY` | hermes config.yaml → mcp_servers.qdrant |
| Context7 | `CONTEXT7_API_KEY` | hermes config.yaml → mcp_servers.context7 |
| AssemblyAI | `ASSEMBLYAI_API_KEY` | `~\.claude\settings.json` → mcpServers.assemblyai |
| TwelveLabs | `TWELVELABS_API_KEY` | `~\.claude\settings.json` → mcpServers.twelvelabs |
| Chroma | `CHROMA_API_KEY` | hermes config.yaml → mcp_servers.chroma |
| Make.com | Bearer token | hermes config.yaml → mcp_servers.make |
| PostMyPost | Bearer token | hermes config.yaml → mcp_servers.postmypost |
| Yougile | `YOUGILE_API_KEY` | hermes config.yaml → mcp_servers.yougile |
| n8n | Bearer JWT | `~\.claude\settings.json` mcpServers.n8n + hermes config.yaml |
| Deepseek (Hermes model) | через Helicone | hermes config.yaml → model.provider: deepseek |
| Miro | `MCP_MARKET_API_KEY` | hermes config.yaml → mcp_servers.miro |
| Google Calendar | `MCP_MARKET_API_KEY` | hermes config.yaml → mcp_servers.google_calendar |
| Smithery | OAuth | `~\.claude\settings.json` → mcpServers.smithery |
| Playwright | нет ключа | npx авто-установка |
| Redis | нет ключа | локальный `redis://localhost:6379/0` |
| Sentry | OAuth | `~\.claude\settings.json` → mcpServers.sentry |

### Локальные MCP (зависят от путей на C:\)

| Сервис | Путь на C:\ | Требует переустановки |
|--------|------------|----------------------|
| Deepgram MCP | `C:\Users\Unknown\AppData\Local\Python\pythoncore-3.14-64\Scripts\deepgram-mcp.exe` | Да (Python pkg) |
| Video Pipeline | `C:\Users\Unknown\Documents\Projects\Hermes + DeepSeek v4 + Telegram\video-pipeline\...` | Да (с Hermes проектом) |
| Redis | localhost:6379 | Да (локальный Redis сервер) |
| Whisper | `C:\Users\Unknown\Documents\Projects\Marketing agency Project\...` | Да (отдельный проект) |

---

## GITHUB (метка репозитория)

> ⚠️ **Этот проект НЕ имеет git-репозитория** (папка `.git` не найдена).  
> Проект существует только локально.

**Рекомендация:** Создать репозиторий перед переносом:
```powershell
cd "E:\Claude code + Telegram Telemost"
git init
git add .gitignore README.md AGENTS.md CHECKLIST.md LESSON-README.md MIGRATION.md notes\ scripts\
# НЕ добавлять: .claude-telegram\.env, .secrets\, logs\, *.db
git commit -m "Initial commit — migration to E: drive"
```

**GitHub токен (для MCP и CLI):**  
Хранится: `~\.claude\settings.json` → `mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN`  
Переменная: `GITHUB_PERSONAL_ACCESS_TOKEN`

---

## CLAUDE OAUTH / API KEY (критично!)

> ⚠️ **ПРОБЛЕМА:** Legacy бот работает в subscription mode (без ANTHROPIC_API_KEY).  
> OAuth токен в `~\.claude\.credentials.json` истекает каждые **~8 часов**.  
> После переноса и перезапуска — бот проработает до истечения OAuth.

**Решение для стабильной работы (рекомендуется при переезде):**
1. Получить постоянный ключ: `claude.ai` → Settings → API Keys → Create key
2. Добавить в `.claude-telegram\.env`: `ANTHROPIC_API_KEY=sk-ant-api03-...`
3. Перезапустить бота

---

## CHECKLIST ПЕРЕНОСА

### Фаза 1 — Подготовка (уже выполнено)
- [x] Инвентаризация всех файлов проекта
- [x] Инвентаризация глобальных зависимостей
- [x] Документирование всех ключей и сервисов
- [x] Создание MIGRATION.md

### Фаза 2 — Копирование
- [ ] Запустить robocopy на E:\
- [ ] Побайтовая верификация

### Фаза 3 — Реконфигурация (после переноса)
- [ ] Обновить пути в `run-claude-telegram-forever.ps1`
- [ ] Обновить пути в `mcp-health-monitor.ps1`
- [ ] Пересоздать Scheduled Tasks с новыми путями
- [ ] Проверить, что 8.3 пути генерируются корректно для E:\

### Фаза 4 — Тестирование
- [ ] Запустить `check-status.ps1` с E:\
- [ ] Написать боту в Telegram — проверить ответ
- [ ] Проверить MCP серверы: `claude mcp list`
- [ ] Проверить логи: нет crash loop

### Фаза 5 — Удаление с C:\
- [ ] Убить все процессы: scheduled tasks → Stop
- [ ] Удалить папку с C:\
- [ ] Пересоздать задачи из E:\

---

## БЫСТРОЕ ВОССТАНОВЛЕНИЕ НА НОВОЙ СИСТЕМЕ

```powershell
# 1. Установить зависимости
npm install -g @anthropic-ai/claude-code
powershell -c "irm bun.sh/install.ps1|iex"  # Bun для Telegram plugin

# 2. Установить Telegram plugin
claude plugin install telegram@claude-plugins-official

# 3. Перенести конфиги (скопировать вручную):
#    ~\.claude\settings.json
#    ~\.claude.json
#    ~\.claude\channels\telegram\.env
#    ~\.claude\channels\telegram\access.json
#    %LOCALAPPDATA%\hermes\config.yaml
#    %LOCALAPPDATA%\hermes\.env

# 4. Настроить токен
.\scripts\configure-telegram-token.ps1

# 5. Пересоздать Scheduled Tasks
# (см. раздел выше)

# 6. Диагностика
.\scripts\check-status.ps1
```

---

## ДИАГНОСТИКА ПОСЛЕ ПЕРЕНОСА

```powershell
# Статус задач
Get-ScheduledTask | Where-Object { $_.TaskName -match "Claude|Telegram|Hermes|MCP" } | Select-Object TaskName, State

# Логи бота
Get-Content "$env:LOCALAPPDATA\foresight-bots\logs\claude-telegram\restart.log" -Tail 20

# Полная диагностика
.\scripts\check-status.ps1
```
