# Claude Code + Telegram

Набор локальных скриптов для запуска Claude Code через официальный Telegram channel plugin.

## Текущий перенос

Проверено 14.06.2026:

| Компонент | Состояние |
| --- | --- |
| Claude Code CLI | установлен: `C:\Users\Unknown\.local\bin\claude.exe`, версия `2.1.177` |
| Bun | установлен: `1.3.14` |
| Telegram plugin | установлен и включен: `telegram@claude-plugins-official`, версия `0.0.6` |
| Telegram token | задан в `C:\Users\Unknown\.claude\channels\telegram\.env` |
| Доступ | `dmPolicy: allowlist`, разрешен Telegram user ID `1064521326` |
| State folder | `C:\Users\Unknown\.claude\channels\telegram` |
| Legacy bridge | сохранен в `.claude-telegram`, бот `@foresight_project_claudecode_bot` |

Секреты в этот проект не копируются. Токен Telegram остается только в `~\.claude\channels\telegram\.env`.

## Два режима

В этой папке теперь есть два варианта Telegram-связки:

| Режим | Когда использовать | Файлы |
| --- | --- | --- |
| Official Claude channel plugin | Предпочтительный режим для новой настройки Claude Code | `scripts\start-claude-telegram.ps1`, `~\.claude\channels\telegram` |
| Legacy `claude-code-telegram` bridge | Сохраненный старый бот с SQLite state и отдельным `.env` | `scripts\start-claude-code-telegram.ps1`, `.claude-telegram` |

Не запускайте два процесса с одним и тем же Telegram token одновременно: Telegram Bot API вернет `409 Conflict`.

## Быстрый старт

Из этой папки:

```powershell
.\scripts\check-status.ps1
.\scripts\start-claude-telegram.ps1
```

Если удобнее отдельное окно PowerShell:

```powershell
.\scripts\open-claude-telegram-window.ps1
```

После запуска сессии напишите боту в Telegram. Claude Code должен быть запущен с channel-флагом:

```powershell
claude --channels plugin:telegram@claude-plugins-official
```

## Скрипты

| Скрипт | Назначение |
| --- | --- |
| `scripts\check-status.ps1` | Проверяет CLI, Bun, plugin, token, allowlist и процессы |
| `scripts\check-status.ps1 -ProbeMcp` | Дополнительно запускает `claude mcp list` |
| `scripts\start-claude-telegram.ps1` | Запускает интерактивную сессию Claude Code с Telegram channel |
| `scripts\open-claude-telegram-window.ps1` | Открывает отдельное окно с Telegram-сессией Claude |
| `scripts\configure-telegram-token.ps1` | Безопасно записывает новый токен из BotFather и обновляет allowlist |
| `scripts\stop-claude-telegram.ps1` | Останавливает только процессы `claude.exe` с Telegram channel-флагом |
| `scripts\start-claude-code-telegram.ps1` | Запускает сохраненный legacy bridge из `.claude-telegram` |
| `scripts\run-claude-telegram-forever.ps1` | Forever-wrapper для legacy bridge |
| `scripts\mcp-health-monitor.ps1` | Legacy watchdog: проверяет MCP и перезапускает scheduled task бота |

## Перенастройка токена

Создайте или обновите бота через [@BotFather](https://t.me/BotFather), затем:

```powershell
.\scripts\configure-telegram-token.ps1
```

Скрипт:

- спросит токен через secure prompt;
- сохранит его в `C:\Users\Unknown\.claude\channels\telegram\.env`;
- сделает backup старого `.env`;
- выставит `dmPolicy: allowlist`;
- добавит user ID `1064521326` в `allowFrom`.

Для другого пользователя:

```powershell
.\scripts\configure-telegram-token.ps1 -AllowUserId "123456789"
```

## Проверка доступа

Файл доступа:

```text
C:\Users\Unknown\.claude\channels\telegram\access.json
```

Текущая схема:

```json
{
  "dmPolicy": "allowlist",
  "allowFrom": ["1064521326"],
  "groups": {},
  "pending": {}
}
```

Если нужен pairing-режим, поменяйте политику:

```powershell
.\scripts\configure-telegram-token.ps1 -DmPolicy pairing
```

Или внутри запущенного Claude Code:

```text
/telegram:access policy pairing
```

## Диагностика

```powershell
.\scripts\check-status.ps1
.\scripts\check-status.ps1 -ProbeMcp
claude plugin list
claude mcp list
```

Если бот не отвечает:

1. Убедитесь, что Claude запущен через `.\scripts\start-claude-telegram.ps1`.
2. Проверьте, что токен есть в `~\.claude\channels\telegram\.env`.
3. Проверьте, что ваш Telegram user ID есть в `allowFrom`.
4. Если включен `allowlist`, неизвестные пользователи будут игнорироваться без ответа.
5. Для групп добавьте group ID через `/telegram:access group add -100...` в Claude Code.

## Что не трогалось

- Старые проекты `OpenClaw + DeepSeek v4 + Telegram` и `Hermes + DeepSeek v4 + Telegram`.
- Существующие Claude MCP серверы и глобальный `~\.claude\settings.json`.
- Запущенный legacy-процесс `claude-telegram-bot.exe`.
