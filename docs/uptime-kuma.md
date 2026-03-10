# Uptime Kuma

Self-hosted uptime monitoring and alerting dashboard for all endurance services.

## Overview

| Item | Value |
|------|-------|
| Image | `louislam/uptime-kuma:1.23.16` |
| Web UI | http://endurance:3001 |
| Network | `endurance_frontend` |
| Data volume | `uptime_kuma_data` |

## Features

- HTTP/TCP/DNS/Docker container monitors
- Telegram, Slack, Discord, email, and 90+ notification providers
- Status page (public or private)
- Response time charts and incident history

## Setup

### 1. Install

```bash
bash provisioning/scripts/module.sh uptime-kuma install
# Edit .env with Telegram credentials
bash provisioning/scripts/module.sh uptime-kuma start
```

### 2. First login

Open http://endurance:3001 and create your admin account.

### 3. Add monitors

Add a monitor for each service:

| Service | Type | URL / Container |
|---------|------|-----------------|
| Portainer | HTTPS | `https://endurance:9443` |
| Pi-hole | HTTP | `http://endurance:8080/admin` |
| MagicMirror² | HTTP | `http://endurance:8181` |
| CI/CD Runner | Docker | `endurance-gh-runner` |
| Backend API | HTTP | `http://endurance:8000/health` |
| NPM Proxy | HTTP | `http://endurance:81` |
| Watchtower | Docker | `endurance-watchtower` |

### 4. Telegram alerts

1. Create a bot with [@BotFather](https://t.me/BotFather) and copy the token into `.env`
2. Get your Chat ID:
   ```bash
   curl "https://api.telegram.org/bot<TOKEN>/getUpdates"
   ```
3. Set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `.env`
4. In the Uptime Kuma UI go to **Settings → Notifications → Add** and enter the token and chat ID

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Europe/Madrid` | Timezone for alert timestamps |
| `TELEGRAM_BOT_TOKEN` | — | Telegram bot token (for reference in install notes) |
| `TELEGRAM_CHAT_ID` | — | Telegram chat ID |

## Data persistence

All monitors, notifications, and history are stored in the `uptime_kuma_data` Docker volume.  
Back it up by copying `/app/data` from the container or by using `docker run --rm -v uptime_kuma_data:/data ...`.

## Removal

```bash
bash provisioning/scripts/module.sh uptime-kuma remove
```

> ⚠️ This removes the volume and all monitoring history.
