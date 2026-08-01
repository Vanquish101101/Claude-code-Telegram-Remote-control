# Урок 1. Настройка моста Telegram: Hermes + Claude Code + Telegram

> **Примечание:** OpenClaw + DeepSeek v4 + Telegram перенесен в отдельный проект:
> `C:\Users\Unknown\Documents\OpenClaw + DeepSeek v4 + Telegram`
> Скрипты запуска и диагностики OpenClaw находятся там.

> **Примечание:** Hermes + DeepSeek v4 + Telegram перенесен в отдельный проект:
> `C:\Users\Unknown\Documents\Hermes + DeepSeek v4 + Telegram`
> Скрипты запуска и диагностики Hermes находятся там.

В этом уроке мы запускаем локальных ассистентов Hermes и Claude Code, подключаем Telegram как канал управления и разбираем, где у системы корневые папки и главные файлы.

## Что уже найдено на этой машине

| Компонент | Состояние |
| --- | --- |
| Hermes | установлен, команда `hermes` доступна |
| OpenClaw | установлен, команда `openclaw` доступна |
| Telegram Desktop | запущен |
| OpenClaw Gateway | настроен на `ws://127.0.0.1:18789`, сейчас не запущен |
| Hermes Gateway | установлен как ручной процесс, сейчас не запущен |
| Claude Code | установлен, команда `claude` доступна |
| Telegram plugin в Claude Code | устанавливается через `claude plugin install telegram@claude-plugins-official` |
| Telegram в Hermes | не настроен |
| Telegram в OpenClaw | не настроен |

## Главная идея

У каждого ассистента есть корневая папка. В ней лежат главный конфиг, рабочие файлы, логи, память, сессии и подключенные интеграции.

| Система | Корневая папка | Главные файлы |
| --- | --- | --- |
| Этот урок | `C:\Users\Unknown\Documents\Lesson 1 (Урок 1)` | `README.md`, `CHECKLIST.md`, `scripts\*.ps1` |
| OpenClaw | `C:\Users\Unknown\.openclaw` | `openclaw.json`, `gateway.cmd`, `agents\main\sessions\sessions.json` |
| Hermes config | `C:\Users\Unknown\AppData\Local\hermes` | `config.yaml`, `.env` |
| Hermes app | `C:\Users\Unknown\AppData\Local\hermes\hermes-agent` | `cli.py`, `gateway\`, `tools\`, `plugins\`, `skills\` |
| Claude MCP | `C:\Users\Unknown\.claude.json` | user-level MCP настройки Claude Code |
| Claude Telegram | `C:\Users\Unknown\.claude\channels\telegram` | `.env`, `access.json`, `approved\`, `inbox\` |

Если что-то ломается, сначала смотрим не "везде", а в корень нужной системы и ее главный конфиг.

## Шаг 1. Проверить базовое состояние

```powershell
.\scripts\check-status.ps1
```

Этот скрипт показывает:

- видны ли команды `hermes` и `openclaw`;
- запущены ли gateway-процессы;
- слушает ли OpenClaw порт `18789`;
- настроены ли каналы Telegram.

## Шаг 2. Получить Telegram Bot Token

1. Откройте Telegram.
2. Найдите `@BotFather`.
3. Выполните `/newbot`.
4. Сохраните выданный токен.

Токен нельзя коммитить, отправлять в чат или вставлять в README. Для настройки используйте скрипт ниже: он спросит токен в консоли и временно передаст его OpenClaw через одноразовый файл.

Если ключи лежат в `C:\Users\Unknown\Documents\Project settings\API Keys.txt`, можно импортировать поддерживаемые переменные в Hermes `.env`:

```powershell
.\scripts\import-project-settings.ps1
```

Если в этом файле позже появится Telegram Bot Token, можно также сразу настроить OpenClaw:

```powershell
.\scripts\import-project-settings.ps1 -ConfigureOpenClawTelegram
```

Для Claude Code лучше завести отдельного Telegram-бота и записать токен в этот же файл как `CLAUDE_TELEGRAM_BOT_TOKEN=...`, затем выполнить:

```powershell
.\scripts\configure-claude-telegram.ps1
```

Скрипт не печатает значения ключей. Отчет без секретов сохраняется в ignored-папку `.secrets`.

## Шаг 3. Подключить Telegram к OpenClaw

```powershell
.\scripts\configure-openclaw-telegram.ps1
```

После этого проверьте:

```powershell
openclaw channels status
```

Прямая CLI-команда, которую выполняет скрипт:

```powershell
openclaw channels add --channel telegram --token-file <temporary-token-file>
```

## Шаг 4. Подключить Telegram к Hermes

> Hermes перенесен в `C:\Users\Unknown\Documents\Hermes + DeepSeek v4 + Telegram`
> Смотрите README и скрипты там.

## Шаг 4a. Подключить Telegram к Claude Code

Официальный Telegram-плагин Claude Code работает как MCP-сервер и требует Bun. Скрипт ниже проверяет Claude Code, устанавливает плагин, проверяет Bun и импортирует токен в `C:\Users\Unknown\.claude\channels\telegram\.env`:

```powershell
.\scripts\configure-claude-telegram.ps1
```

Если Bun не установлен:

```powershell
powershell -c "irm bun.sh/install.ps1|iex"
```

Запуск интерактивного Claude Code с Telegram-каналом:

```powershell
.\scripts\start-claude-telegram-bridge.ps1
```

После запуска:

1. Напишите боту в Telegram.
2. Бот пришлет pairing-код.
3. В Claude Code выполните:

```text
/telegram:access pair <code>
```

После успешного pairing закройте свободную выдачу кодов:

```text
/telegram:access policy allowlist
```

## Шаг 5. Запустить gateway

OpenClaw:

```powershell
.\scripts\start-openclaw-gateway.ps1
```

Проверка OpenClaw:

```powershell
openclaw status
```

OpenClaw dashboard после запуска будет здесь:

```text
http://127.0.0.1:18789/
```

## Шаг 6. Первая задача из Telegram

После настройки Telegram отправьте боту простую команду:

```text
Привет. Напиши короткий план на сегодня из 3 пунктов.
```

Потом задачу с файловым контекстом:

```text
Посмотри папку урока и объясни, какие здесь главные файлы.
```

Для проверки отправки без LLM у Hermes можно использовать:

```powershell
hermes send --to telegram "Проверка доставки из Hermes"
```

Для OpenClaw:

```powershell
openclaw message send --channel telegram --target <chat-id-or-username> --message "Проверка доставки из OpenClaw"
```

## Шаг 7. MCP: внешние сервисы

MCP-серверы добавляют ассистентам инструменты: GitHub, Supabase, браузер, базы данных, файлы и другие сервисы.

Hermes:

```powershell
hermes mcp list
hermes mcp add
hermes mcp test
```

OpenClaw:

```powershell
openclaw mcp list
openclaw mcp add
openclaw mcp probe
```

Claude Code user-level MCP сейчас централизован в:

```text
C:\Users\Unknown\.claude.json
```

## Если не работает

Запустите диагностику:

```powershell
.\scripts\check-status.ps1
openclaw doctor
hermes doctor
```

Типичные причины:

- gateway не запущен;
- Telegram-токен не добавлен;
- бот не получил первое сообщение от пользователя;
- для Claude Code не установлен Bun или сессия запущена без `--channels plugin:telegram@claude-plugins-official`;
- порт `18789` занят или OpenClaw gateway disabled;
- MCP добавлен не в тот конфиг.

## Правило безопасности

Секреты живут только в конфиге конкретного инструмента или в локальной ignored-папке `.secrets`. В учебные файлы и git они не попадают.
