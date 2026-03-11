# Endurance — Home Server Platform

A modular, Docker-based home server platform for **Debian 13**. Every service runs as an independent Docker Compose module that can be installed, started, stopped, updated, and removed through a unified CLI or an interactive TUI console.

```
hostname: endurance
target:   Debian 13 (fresh install)
stack:    Docker Engine + Compose · Zsh + OMZ · Portainer · Pi-hole
          MagicMirror² · GitHub Actions runner · FastAPI backend template
          Uptime Kuma · Watchtower · Nginx Proxy Manager · Helix Agent
```

## Table of Contents

- [Endurance — Home Server Platform](#endurance--home-server-platform)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [Quick Start](#quick-start)
  - [Project Structure](#project-structure)
  - [Base Provisioning](#base-provisioning)
    - [What It Does](#what-it-does)
    - [CLI Flags](#cli-flags)
  - [Module Management](#module-management)
    - [Available Actions](#available-actions)
    - [Examples](#examples)
  - [TUI Console](#tui-console)
    - [Menu Structure](#menu-structure)
  - [CI/CD](#cicd)
    - [Self-Hosted Runner](#self-hosted-runner)
    - [Workflows](#workflows)
  - [Adding a New Service](#adding-a-new-service)
  - [Module Documentation](#module-documentation)
  - [Assumptions](#assumptions)
  - [License](#license)

## Features

- **Idempotent provisioning** — safe to re-run; completed steps are skipped
- **Independent modules** — each service can be toggled individually
- **Professional TUI** — animated spinners, Unicode boxes, interactive menus
- **Self-hosted CI/CD** — GitHub Actions runner deploys on push
- **Docker-first** — all services containerized with health checks
- **Shared networks** — `endurance_frontend` (exposed) and `endurance_backend` (internal)
- **Reverse proxy** — Nginx Proxy Manager with Let's Encrypt SSL behind `endurance.local`
- **Monitoring** — Uptime Kuma with Telegram alerts for all services
- **Auto-updates** — Watchtower keeps images current on a weekly schedule

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Debian | 13 (fresh install recommended) |
| Root access | `sudo` capable user |
| Internet | Required for initial setup |

The provisioning script installs everything else (Docker, Zsh, OMZ, Powerlevel10k).

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/j4ngx/homeserver.git
cd homeserver

# 2. Run base provisioning (as root or with sudo)
sudo bash provisioning/scripts/provision.sh

# 3. Launch the interactive TUI
sudo bash tui/endurance_tui.sh

# --- OR manage modules directly ---
# Install and start a module
bash provisioning/scripts/module.sh portainer install
bash provisioning/scripts/module.sh portainer start

# Check status of all modules
bash provisioning/scripts/module.sh list
```

## Project Structure

```
homeserver/
├── .github/
│   └── workflows/
│       ├── backend-template.yml  # CI/CD workflow for backend
│       └── healthcheck.yml       # Scheduled health check workflow
├── provisioning/
│   └── scripts/
│       ├── provision.sh        # Base system provisioning
│       └── module.sh           # Unified module manager CLI
├── modules/
│   ├── portainer/              # Docker management UI
│   ├── pihole/                 # Network-wide ad blocker
│   ├── magicmirror/            # Smart display dashboard
│   ├── cicd-runner/            # GitHub Actions self-hosted runner
│   ├── backend-template/       # Reference backend API (FastAPI)
│   ├── uptime-kuma/            # Service monitoring & alerting
│   ├── watchtower/             # Automatic container image updater
│   ├── nginx-proxy-manager/    # Reverse proxy + Let's Encrypt SSL
│   ├── helix-agent/            # Personal AI Telegram assistant
│   ├── magicmirror/            # Smart display dashboard
│   ├── cicd-runner/            # GitHub Actions self-hosted runner
│   └── backend-template/       # Reference backend API (FastAPI)
├── tui/
│   ├── endurance_tui.sh        # Interactive TUI console
│   └── lib/
│       └── endurance_tui_lib.sh # TUI primitives library
├── ci/                         # Workflow templates (reference copies)
│   ├── backend-template.yml
│   └── healthcheck.yml
└── docs/
    ├── README.md               # ← You are here
    ├── portainer.md
    ├── pihole.md
    ├── magicmirror.md
    ├── cicd-runner.md
    ├── backend-template.md
    ├── uptime-kuma.md
    ├── watchtower.md
    ├── nginx-proxy-manager.md
    └── helix-agent.md
```

## Base Provisioning

The provisioning script transforms a fresh Debian 13 installation into a Docker-ready server.

### What It Does

| Step | Description |
|------|-------------|
| System update | `apt update && apt upgrade` |
| Hostname | Sets hostname to `endurance` |
| Core packages | git, curl, wget, unzip, htop, jq, etc. |
| Docker | Installs Docker Engine + Compose plugin from official repo |
| Zsh | Installs Zsh + Oh My Zsh + Powerlevel10k + plugins |
| Docker networks | Creates `endurance_frontend` and `endurance_backend` |
| Module dirs | Ensures all module directories exist |
| Firewall | Configures UFW with default deny + rules for each module |

### CLI Flags

```bash
sudo bash provisioning/scripts/provision.sh [OPTIONS]

  --user <name>       Target user (default: $SUDO_USER)
  --hostname <name>   Override hostname (default: endurance)
  --skip-zsh          Skip Zsh/OMZ/p10k installation
  --verbose           Enable verbose output
  -h, --help          Show usage
```

## Module Management

Every module is managed through `module.sh`:

```bash
bash provisioning/scripts/module.sh <module> <action>
```

### Available Actions

| Action | Description |
|--------|-------------|
| `install` | Copy `.env.example` → `.env`, run pre-install hooks |
| `start` | `docker compose up -d` |
| `stop` | `docker compose stop` (containers preserved) |
| `restart` | `docker compose restart` |
| `update` | `docker compose pull && up -d --force-recreate` |
| `status` | Show container status |
| `logs` | Tail container logs (50 lines) |
| `remove` | Stop + remove containers **and volumes** (destructive) |
| `list` | Show all modules and their running state |

### Examples

```bash
# Install and start Pi-hole
bash provisioning/scripts/module.sh pihole install
bash provisioning/scripts/module.sh pihole start

# Update all images for Portainer
bash provisioning/scripts/module.sh portainer update

# Check what's running
bash provisioning/scripts/module.sh list
```

## TUI Console

Launch the interactive console:

```bash
sudo bash tui/endurance_tui.sh
```

### Menu Structure

```
Main Menu
├── 1. Base system provisioning
├── 2. Module management
│     ├── Select module → Install / Start / Stop / Restart / Update / Status / Logs / Remove / Edit .env
├── 3. System health dashboard
├── 4. Quick actions (start/stop all, prune, list containers)
├── 5. About
└── q. Quit
```

The TUI uses the same professional UI primitives as the GLaDOS installer: Unicode box-drawing, animated spinners, coloured output, and interactive prompts.

## CI/CD

### Self-Hosted Runner

The `cicd-runner` module provides a GitHub Actions self-hosted runner. Two deployment options:

1. **Docker** (recommended) — `docker compose up -d`
2. **Native systemd** — `bash modules/cicd-runner/install-native.sh`

### Workflows

Workflows live in `.github/workflows/`. Reference templates are also kept in `ci/` for easy copying:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `backend-template.yml` | Push to `main` (modules/backend-template/**) | Test + deploy backend |
| `healthcheck.yml` | Cron `0 8 * * *` + manual | Daily health check of all modules |

## Adding a New Service

1. **Copy the template:**
   ```bash
   cp -r modules/backend-template modules/my-new-service
   ```

2. **Edit `docker-compose.yml`** — change service name, ports, image.

3. **Edit `.env.example`** — add service-specific variables.

4. **Update the TUI** — add the module name to the registry in `tui/endurance_tui.sh`.

5. **Create CI workflow** — copy `.github/workflows/backend-template.yml` and adjust paths/names.

6. **Install and start:**
   ```bash
   bash provisioning/scripts/module.sh my-new-service install
   bash provisioning/scripts/module.sh my-new-service start
   ```

## Module Documentation

| Module | Docs | Default Ports |
|--------|------|---------------|
| Portainer | [docs/portainer.md](portainer.md) | 9000 (HTTP) · 9443 (HTTPS) |
| Pi-hole | [docs/pihole.md](pihole.md) | 53 (DNS) · 8080 (Web UI) |
| MagicMirror² | [docs/magicmirror.md](magicmirror.md) | 8181 |
| CI/CD Runner | [docs/cicd-runner.md](cicd-runner.md) | — |
| Backend Template | [docs/backend-template.md](backend-template.md) | 8000 |
| Uptime Kuma | [docs/uptime-kuma.md](uptime-kuma.md) | 3001 |
| Watchtower | [docs/watchtower.md](watchtower.md) | — (internal) |
| Nginx Proxy Manager | [docs/nginx-proxy-manager.md](nginx-proxy-manager.md) | 80 · 443 · 81 (Admin) |
| Helix Agent | [docs/helix-agent.md](helix-agent.md) | — (Telegram bot, no exposed ports) |

## Assumptions

| Setting | Value |
|---------|-------|
| Main user | `$SUDO_USER` |
| LAN subnet | 192.168.1.0/24 |
| Server IP | 192.168.1.50 |
| SSH port | 22 |
| Docker networks | `endurance_frontend`, `endurance_backend` |

## License

MIT
