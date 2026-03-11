# Helix Agent

Personal AI assistant running on Telegram, backed by Groq/OpenRouter LLMs and
Firebase Firestore for persistent memory. Deployed as a Docker container on the
Endurance home server.

## Overview

| Setting | Value |
|---|---|
| Container name | `endurance-helix-agent` |
| Image | `endurance-helix-agent:latest` (built locally) |
| Ports | None exposed (outbound-only: Telegram long-polling + Firestore) |
| Restart policy | `unless-stopped` |
| Source repo | `j4ngx/axon_agent` |

## Features

- **Telegram interface** — long-polling via aiogram v3 (no webhook ports needed)
- **Multi-LLM** — Groq (primary) + OpenRouter (fallback), automatic failover
- **Tool system** — extensible via built-in tools, skills, or MCP servers
- **Persistent memory** — Firestore conversation history per user
- **Reminders & scheduler** — one-time and recurring reminders delivered via Telegram
- **Google Workspace** — Gmail, Calendar, and Sheets via `gog` CLI
- **Structured logging** — JSON output with automatic secret redaction

## Installation

```bash
# 1. Install the module (clones source + validates service account)
bash provisioning/scripts/module.sh helix-agent install

# 2. Edit secrets
nano modules/helix-agent/.env

# 3. Start
bash provisioning/scripts/module.sh helix-agent start
```

### Prerequisites

Before installing, you need:

1. **Telegram bot token** — create one via [@BotFather](https://t.me/BotFather)
2. **Telegram user ID** — get yours from [@userinfobot](https://t.me/userinfobot)
3. **Groq API key** — [console.groq.com/keys](https://console.groq.com/keys)
4. **Firebase service account** — download from Firebase Console → Project Settings → Service Accounts → Generate New Private Key
5. Copy the service account JSON to `modules/helix-agent/service-account.json`

### Environment Variables (`.env`)

| Variable | Description | Required |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather | Yes |
| `TELEGRAM_ALLOWED_USER_IDS` | JSON array of allowed Telegram user IDs | Yes |
| `GROQ_API_KEY` | Groq API key (primary LLM) | Yes |
| `OPENROUTER_API_KEY` | OpenRouter API key (fallback LLM) | No |

### Application Settings (`config.yml`)

Non-secret settings live in `config.yml`:

- **LLM providers** — models, timeouts, primary/fallback selection
- **Agent** — max iterations, history window, system prompt path
- **Memory** — Firestore project ID
- **Logging** — log level
- **Skills** — built-in tools and MCP server connections

## Architecture

```
Telegram → Handlers → AgentLoop → LLM (Groq/OpenRouter)
                         ↕              ↕
                      Memory         Tools/Skills
                   (Firestore)       (Registry)
                         ↑
               SchedulerService ──→ Telegram (notifications)
```

The `AgentLoop` implements a think-act-observe cycle: it calls the LLM,
executes any requested tools, feeds results back, and repeats until it gets
a final text answer or hits the iteration limit (default: 5).

## Firestore Data Model

All persistent data is stored in Cloud Firestore (project `axon-429c0`).

```
(default) database
└── users/{user_id}
    ├── messages/{message_id}     # Chat history
    │   ├── role: string
    │   ├── content: string
    │   └── timestamp: timestamp
    └── reminders/{reminder_id}   # Scheduled reminders
        ├── user_id: number
        ├── message: string
        ├── trigger_at: timestamp
        ├── recurrence: string | null   (daily | weekdays | weekly | monthly)
        ├── status: string              (pending | completed | cancelled)
        └── created_at: timestamp
```

A composite index on `reminders` (collection group: `status` ASC + `trigger_at` ASC)
is required for the scheduler's cross-user query and is deployed via
`firebase deploy --only firestore:indexes`.

## Built-in Tools

| Tool | Description |
|---|---|
| `get_current_time` | Returns current date and time |
| `gog` | Google Workspace — Gmail search/send, Calendar events, Sheets read/write |
| `reminder` | Create, list, and cancel scheduled reminders |

### Reminders

Users can schedule reminders through natural language. The `SchedulerService`
runs as a background task (every 30 s), queries Firestore for due reminders,
and delivers them as Telegram messages.

**Supported commands:**

| Command | Description | Required Params |
|---|---|---|
| `create` | Schedule a new reminder | `message`, `trigger_at` |
| `list` | Show all pending reminders | — |
| `cancel` | Cancel a reminder by ID | `reminder_id` |

**Recurrence patterns:**

| Pattern | Behaviour |
|---|---|
| _(none)_ | One-time — fires once, then marked completed |
| `daily` | Every day at the same time |
| `weekdays` | Monday–Friday, skips weekends |
| `weekly` | Same day every week |
| `monthly` | Same day each month (capped at 28th) |

## Volume Mounts

| Host Path | Container Path | Mode | Purpose |
|---|---|---|---|
| `helix-data` (named volume) | `/app/data` | rw | Persistent cache |
| `./service-account.json` | `/app/service-account.json` | ro | Firebase credentials |
| `./config.yml` | `/app/config.yml` | ro | Application config |

## Health Check

The container health check verifies that the `helix` Python package is importable:

```yaml
healthcheck:
  test: ["CMD", "python", "-c", "import helix"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 20s
```

## Operations

```bash
# Start
bash provisioning/scripts/module.sh helix-agent start

# Stop
bash provisioning/scripts/module.sh helix-agent stop

# Restart
bash provisioning/scripts/module.sh helix-agent restart

# Logs
bash provisioning/scripts/module.sh helix-agent logs

# Rebuild after source code changes
bash provisioning/scripts/module.sh helix-agent update

# Remove (destructive — deletes data volume)
bash provisioning/scripts/module.sh helix-agent remove
```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Bot doesn't respond | Wrong `TELEGRAM_BOT_TOKEN` | Check `.env` and restart |
| "I don't have access to your emails" | `gog` skill disabled or not configured | Ensure `gog` is enabled in `config.yml` and OAuth is set up |
| Reminders not firing | Composite index not deployed | Run `firebase deploy --only firestore:indexes` |
| `PERMISSION_DENIED` from Firestore | Invalid service account | Re-download from Firebase Console and replace `service-account.json` |
| Container unhealthy | Source code not cloned | Run `module.sh helix-agent install` first |
