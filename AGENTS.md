# Local Agent Notes

This lesson uses the local file below as the source of user-provided API keys:

```text
C:\Users\Unknown\Documents\Project settings\API Keys.txt
```

Rules:

- Never print raw API keys, tokens, secrets, JWTs, or credentials from that file.
- Use `scripts\import-project-settings.ps1` to import supported keys into local tool configs.
- The importer writes a report without secret values to `.secrets\project-settings-import-report.json`.
- `.secrets\` is gitignored and must stay out of commits.
- If the user adds more keys to `API Keys.txt`, rerun:

```powershell
.\scripts\import-project-settings.ps1 -ConfigureOpenClawTelegram
```

Current state:
- Hermes: TELEGRAM_BOT_TOKEN set in `.env`, model switched to `deepseek-chat` (provider: deepseek), DEEPSEEK_API_KEY present in `.env`.
- OpenClaw: Telegram channel disabled (old bot deleted; no separate OpenClaw bot created yet). DeepSeek configured via `DEEPSEEK_API_KEY` in `.openclaw\.env`. Re-enable Telegram in `openclaw.json` only after creating a separate bot via @BotFather and writing its token to `.openclaw\secrets\telegram-bot-token.txt`.
- Claude Code: official `telegram@claude-plugins-official` plugin installed and Bun installed. No Claude-specific Telegram token was found in `API Keys.txt`; add `CLAUDE_TELEGRAM_BOT_TOKEN=...`, rerun `scripts\configure-claude-telegram.ps1`, then start with `scripts\start-claude-telegram-bridge.ps1`.
