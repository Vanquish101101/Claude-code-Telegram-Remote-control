# Корневые папки и главные файлы

Главная практическая идея урока: ассистент - это не "магия в чате", а набор папок, конфигов, процессов и каналов связи.

## Этот урок

Корень:

```text
C:\Users\Unknown\Documents\Lesson 1 (Урок 1)
```

Главные файлы:

```text
README.md
CHECKLIST.md
scripts\check-status.ps1
scripts\configure-openclaw-telegram.ps1
scripts\configure-claude-telegram.ps1
scripts\start-claude-telegram-bridge.ps1
scripts\start-openclaw-gateway.ps1
scripts\start-hermes-gateway.ps1
```

## OpenClaw

Корень:

```text
C:\Users\Unknown\.openclaw
```

Главные файлы:

```text
openclaw.json
gateway.cmd
agents\main\sessions\sessions.json
```

Что искать:

- `openclaw.json` - gateway, токены, каналы, workspace, skills;
- `gateway.cmd` - как запускается gateway;
- `agents\main\sessions\` - история локального агента;
- `workspace\` - рабочая зона OpenClaw.

## Hermes

Config root:

```text
C:\Users\Unknown\AppData\Local\hermes
```

Главные файлы:

```text
config.yaml
.env
```

App root:

```text
C:\Users\Unknown\AppData\Local\hermes\hermes-agent
```

Что искать:

- `config.yaml` - модель, провайдеры, toolsets, gateway-настройки;
- `.env` - секреты и API-ключи;
- `gateway\` - код messaging gateway;
- `tools\`, `plugins\`, `skills\` - инструменты ассистента.

## Claude Code MCP

User-level конфиг:

```text
C:\Users\Unknown\.claude.json
```

Что искать:

- `mcpServers` - подключенные MCP-серверы;
- команды запуска MCP;
- переменные окружения и ссылки на секреты.

## Claude Code Telegram

User-level канал:

```text
C:\Users\Unknown\.claude\channels\telegram
```

Главные файлы:

```text
.env
access.json
approved\
inbox\
```

Что искать:

- `.env` - `TELEGRAM_BOT_TOKEN` для официального Telegram-плагина Claude Code;
- `access.json` - pairing, allowlist и политика доступа;
- `approved\` - служебные подтверждения pairing;
- `inbox\` - входящие фото и файлы из Telegram.
