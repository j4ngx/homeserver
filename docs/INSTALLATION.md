# Endurance — Installation and Configuration Guide

> **Target OS:** Debian 13 · **Hostname:** `endurance`  
> **Audience:** Advanced Linux engineer / senior DevOps  
> **Last updated:** March 2026

---

## Table of Contents

1. [Overview](#1-overview)
2. [Assumptions](#2-assumptions)
3. [Architecture](#3-architecture)
4. [Step-by-Step Installation](#4-step-by-step-installation)
   - 4.1 [System Preparation](#41-system-preparation)
   - 4.2 [Project Checkout and Layout](#42-project-checkout-and-layout)
   - 4.3 [Base Provisioning](#43-base-provisioning)
5. [Module Configuration and Startup](#5-module-configuration-and-startup)
   - 5.1 [CI/CD Runner](#51-cicd-runner)
   - 5.2 [Portainer](#52-portainer)
   - 5.3 [Pi-hole](#53-pi-hole)
   - 5.4 [MagicMirror²](#54-magicmirror)
   - 5.5 [Backend Applications](#55-backend-applications)
6. [TUI Installer](#6-tui-installer)
7. [Operations and Maintenance](#7-operations-and-maintenance)
8. [Backup Considerations](#8-backup-considerations)

---

## 1. Overview

**Endurance** is a modular, Docker-based home server platform running on **Debian 13**. Every service is packaged as an independent Docker Compose module that can be installed, started, stopped, updated, and removed through a unified CLI helper or an interactive terminal UI.

| Attribute | Value |
|-----------|-------|
| Hostname | `endurance` |
| OS | Debian 13 (Trixie) |
| Containerisation | Docker Engine + Compose plugin (v2) |
| CI/CD | GitHub Actions with a self-hosted runner on `endurance` |
| Shell | Zsh + Oh My Zsh + Powerlevel10k |

### Included modules

| Module | Port(s) | Description |
|--------|---------|-------------|
| Portainer | 9000 (HTTP, localhost only) / 9443 (HTTPS, LAN) | Docker management UI |
| Pi-hole | 53 (DNS) / 8080 (Web UI) | Network-wide ad blocker |
| MagicMirror² | 8181 | Smart display dashboard |
| CI/CD Runner | — | GitHub Actions self-hosted runner |
| Backend Template | 8000 | Reference FastAPI service / deployment pattern |

---

## 2. Assumptions

- A **fresh Debian 13** installation with a non-root user that has `sudo` access.
- Basic **network connectivity** is established (DHCP or static IP).
- The server has a **static LAN IP address** (examples in this guide use `192.168.1.50`; adjust to your environment).
- You have access to **GitHub** and can generate Personal Access Tokens (PATs).
- The main OS user is identified automatically from `$SUDO_USER`; override with `--user <username>` if needed.
- The repository is cloned to `/home/<user>/homeserver` (or any path you prefer; scripts use relative paths from the project root).
- `systemd-resolved` stub listener may conflict with Pi-hole on port 53 — handled in [§ 5.3](#53-pi-hole).

---

## 3. Architecture

```
                          ┌──────────────────────────────────────────────┐
                          │               endurance (Debian 13)           │
                          │                  192.168.1.50                 │
                          │                                               │
                          │  ┌─────────────────────────────────────────┐ │
                          │  │           Docker Engine (host)          │ │
                          │  │                                         │ │
                          │  │   endurance_frontend  (bridge network)  │ │
                          │  │  ┌──────────┐  ┌──────────┐  ┌──────┐  │ │
                          │  │  │Portainer │  │ Pi-hole  │  │  MM² │  │ │
                          │  │  │:9000/9443│  │:53/:8080 │  │:8181 │  │ │
                          │  │  └──────────┘  └──────────┘  └──────┘  │ │
                          │  │                                         │ │
                          │  │   endurance_backend   (bridge network)  │ │
                          │  │  ┌──────────────┐  ┌────────────────┐  │ │
                          │  │  │  GH Runner   │  │ Backend Apps   │  │ │
                          │  │  │  (internal)  │  │    :8000+      │  │ │
                          │  │  └──────────────┘  └────────────────┘  │ │
                          │  └─────────────────────────────────────────┘ │
                          │                                               │
                          │  /var/run/docker.sock ◄── Portainer (ro)     │
                          │                       ◄── GH Runner (rw)     │
                          └──────────────────────────────────────────────┘
                                          │  LAN (192.168.1.0/24)
                         ┌────────────────┴────────────────┐
                   Browsers / tablets                 Router DNS
                   http://endurance:8181            → 192.168.1.50:53
                   https://endurance:9443
                   http://endurance:8080/admin

                          ┌──────────────────────────────────┐
                          │       GitHub (cloud)             │
                          │  repository: j4ngx/homeserver    │
                          │      ↓ push to main              │
                          │  GitHub Actions workflow         │
                          │      ↓ runs-on: endurance        │
                          │  Self-hosted runner container    │
                          │      ↓ docker compose up -d      │
                          │  Backend module updated          │
                          └──────────────────────────────────┘
```

### Component relationships

- **`endurance_frontend`** — bridge network shared by Portainer, Pi-hole, MagicMirror², and backend services that expose LAN-facing ports.
- **`endurance_backend`** — internal network for the CI/CD runner and backend services; not exposed to the LAN directly.
- **CI/CD runner** mounts `/var/run/docker.sock` (read-write) to build images and run `docker compose` commands during workflow jobs.
- **Portainer** mounts `/var/run/docker.sock` read-only for introspection.
- The hostname `endurance` resolves on the LAN via router DNS or `/etc/hosts` entries on client devices.

---

## 4. Step-by-Step Installation

### 4.1 System Preparation

> These steps are performed **manually** on a fresh Debian 13 host before cloning the repository. The provisioning script (§ 4.3) automates everything from step 4 onward, but the steps below are documented for transparency and disaster-recovery purposes.

#### 4.1.1 Update and upgrade packages

```bash
sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y && sudo apt-get autoclean
```

#### 4.1.2 Set the hostname

```bash
sudo hostnamectl set-hostname endurance

# /etc/hostname
echo "endurance" | sudo tee /etc/hostname

# /etc/hosts — add 127.0.1.1 entry if missing
grep -q "^127.0.1.1" /etc/hosts \
  && sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\tendurance/" /etc/hosts \
  || echo -e "127.0.1.1\tendurance" | sudo tee -a /etc/hosts
```

Verify:

```bash
hostname          # should output: endurance
hostname --fqdn   # should output: endurance
```

#### 4.1.3 Install base tools

```bash
sudo apt-get install -y \
  git curl wget unzip ca-certificates \
  gnupg lsb-release apt-transport-https software-properties-common \
  jq htop tree ncdu tmux ufw fail2ban
```

#### 4.1.4 Install Docker Engine and the Compose plugin

```bash
# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker stable repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Enable and start the daemon
sudo systemctl enable --now docker

# Verify
docker --version          # Docker version 27.x.y
docker compose version    # Docker Compose version v2.x.y
```

#### 4.1.5 Configure the main user

```bash
# Add user to the docker group (replace <user> with your username)
sudo usermod -aG docker <user>

# Activate the new group without logging out
newgrp docker
```

> **Note:** Group membership applies to new login sessions. Either `newgrp docker` or log out and back in.

#### 4.1.6 Install Zsh, Oh My Zsh, and Powerlevel10k (non-interactive)

```bash
# Install Zsh
sudo apt-get install -y zsh

# Oh My Zsh (non-interactive — does not switch shell or open Zsh)
RUNZSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Powerlevel10k theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  ~/.oh-my-zsh/custom/themes/powerlevel10k

# zsh-autosuggestions and zsh-syntax-highlighting plugins
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
  ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
  ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Apply theme and plugins to ~/.zshrc
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
sed -i 's/^plugins=.*/plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# Set Zsh as default shell
chsh -s "$(which zsh)"
```

Run the provisioning script (§ 4.3) to have all of this done automatically and idempotently.

---

### 4.2 Project Checkout and Layout

#### Clone the repository

```bash
git clone https://github.com/j4ngx/homeserver.git ~/homeserver
cd ~/homeserver
```

#### Directory structure

```
homeserver/                         ← PROJECT_ROOT
├── .github/
│   └── workflows/
│       ├── backend-template.yml    # CI/CD pipeline for backend-template
│       └── healthcheck.yml         # Daily health check across all modules
├── ci/                             # Reference copies of workflow templates
│   ├── backend-template.yml
│   └── healthcheck.yml
├── docs/                           # Documentation (this file lives here)
├── modules/                        # One directory per deployable service
│   ├── portainer/
│   │   └── docker-compose.yml
│   ├── pihole/
│   │   ├── docker-compose.yml
│   │   └── .env.example
│   ├── magicmirror/
│   │   ├── docker-compose.yml
│   │   ├── config/config.js        # MagicMirror configuration (edit this)
│   │   ├── css/custom.css
│   │   └── modules/                # Third-party MagicMirror modules
│   ├── cicd-runner/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── install-native.sh       # Alternative: systemd-based runner
│   └── backend-template/
│       ├── docker-compose.yml
│       ├── Dockerfile
│       ├── main.py
│       ├── requirements.txt
│       └── tests/test_main.py
├── provisioning/
│   └── scripts/
│       ├── provision.sh            # Base system provisioning (idempotent)
│       └── module.sh               # Unified module manager CLI
└── tui/
    ├── endurance_tui.sh            # Interactive TUI console
    └── lib/
        └── endurance_tui_lib.sh    # TUI primitives library
```

Module data persisted by Docker named volumes is stored inside the Docker volume store (`/var/lib/docker/volumes/`). There are no explicit bind-mounts to `/srv`; module configuration files live inside the project tree under `modules/<name>/`.

---

### 4.3 Base Provisioning

The provisioning script is **idempotent**: every step checks whether it has already been applied and skips it gracefully. It is safe to re-run after a partial failure or a system update.

#### Run provisioning

```bash
sudo bash provisioning/scripts/provision.sh
```

Optional flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--user <username>` | `$SUDO_USER` | OS user to configure |
| `--hostname <name>` | `endurance` | Target hostname |
| `--skip-zsh` | off | Skip Zsh/OMZ/P10k installation |
| `--verbose` | off | Print additional output |

Example — provision with an explicit username:

```bash
sudo bash provisioning/scripts/provision.sh --user alice
```

#### What provisioning does

| Step | Description |
|------|-------------|
| 1 | `apt-get update` + `upgrade` + `dist-upgrade` |
| 2 | Set hostname to `endurance` in `/etc/hostname` and `/etc/hosts` |
| 3 | Install core packages: `git curl wget unzip ca-certificates gnupg jq htop tmux ufw fail2ban` and more |
| 4 | Install Docker Engine + Compose plugin from the official Docker repository; enable `docker.service`; add user to `docker` group |
| 5 | Install Zsh + Oh My Zsh + Powerlevel10k + `zsh-autosuggestions` + `zsh-syntax-highlighting`; set Zsh as default shell |
| 6 | Create Docker bridge networks `endurance_frontend` and `endurance_backend` |
| 7 | Create module directories under `modules/` |
| 8 | Configure UFW: default deny-in, allow-out; open ports 22, 53, 8080, 8181, 9443, 8000 |

#### Verify provisioning

```bash
# Docker running
systemctl is-active docker          # active

# Docker Compose plugin
docker compose version              # Docker Compose version v2.x.y

# Docker networks
docker network ls | grep endurance
# endurance_frontend   bridge   local
# endurance_backend    bridge   local

# Hostname
hostname                            # endurance

# User in docker group
groups                              # ... docker ...

# UFW
sudo ufw status                     # Status: active, rules listed
```

---

## 5. Module Configuration and Startup

All modules are managed through the unified CLI:

```bash
bash provisioning/scripts/module.sh <module_name> <action>
```

Available actions: `install`, `start`, `stop`, `restart`, `update`, `status`, `logs`, `remove`, `list`.

The `install` action copies `.env.example` → `.env` (if `.env` does not yet exist) and runs any module-specific `install.sh` hook. **Edit the `.env` file before calling `start`.**

---

### 5.1 CI/CD Runner

#### Purpose

A GitHub Actions self-hosted runner that executes deployment jobs directly on `endurance`. It mounts the host's Docker socket so workflows can build images and run `docker compose` commands.

#### Prerequisites

- A GitHub Personal Access Token (PAT) with `repo` scope (for repository-level runners) or `admin:org` scope (for org-level runners).
- The repository and organisation/owner names.

#### Generate a GitHub PAT

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**.
2. Click **Generate new token (classic)**.
3. Select the `repo` scope.
4. Set a meaningful expiry (e.g. 1 year) and copy the token immediately.

Alternatively, use a **fine-grained PAT** scoped to the specific repository with *Actions: read and write* and *Administration: read and write* permissions.

#### Configure

```bash
bash provisioning/scripts/module.sh cicd-runner install
nano modules/cicd-runner/.env
```

`modules/cicd-runner/.env`:

```dotenv
RUNNER_NAME=endurance-runner
RUNNER_LABELS=self-hosted,linux,endurance
RUNNER_SCOPE=repo
GITHUB_OWNER=your-github-username
GITHUB_REPO=homeserver
RUNNER_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
DISABLE_AUTO_UPDATE=false
EPHEMERAL=false
```

| Variable | Required | Description |
|----------|----------|-------------|
| `GITHUB_OWNER` | Yes | GitHub username or organisation |
| `GITHUB_REPO` | Yes (for `repo` scope) | Repository name |
| `RUNNER_TOKEN` | Yes | PAT or registration token |
| `RUNNER_LABELS` | No | Comma-separated labels; must match `runs-on` in workflows |
| `RUNNER_SCOPE` | No | `repo` (default), `org`, or `enterprise` |
| `EPHEMERAL` | No | `true` = runner deregisters after each job |

#### Start

```bash
bash provisioning/scripts/module.sh cicd-runner start
```

#### Verify the runner is online

1. Open **GitHub → repository → Settings → Actions → Runners**.
2. The runner `endurance-runner` should appear with status **Idle** (green dot).

```bash
# Confirm container is healthy
bash provisioning/scripts/module.sh cicd-runner status

# Watch registration output
bash provisioning/scripts/module.sh cicd-runner logs
# Look for: "Running job" or "Listening for Jobs"
```

#### Integration with workflows

Workflows that should run on `endurance` must specify the matching labels:

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, endurance]
```

The runner mounts `/var/run/docker.sock` (read-write), so workflow steps can call `docker compose build`, `docker compose up -d`, etc., directly on the host daemon.

#### Alternative: native systemd runner

If you prefer a systemd service over Docker:

```bash
sudo bash modules/cicd-runner/install-native.sh \
  --owner your-github-username \
  --repo homeserver \
  --token ghp_xxxxxxxxxxxxxxxxxxxx
```

The script installs the runner binary to `/opt/actions-runner`, creates a `github-runner` system user, and registers a systemd unit. Use `systemctl status github-runner` to manage it.

---

### 5.2 Portainer

#### Purpose

Portainer CE provides a full-featured web UI to inspect and manage containers, images, volumes, and networks on the host Docker daemon.

#### Prerequisites

None. Portainer requires no environment variables.

#### Configure and start

```bash
bash provisioning/scripts/module.sh portainer install
bash provisioning/scripts/module.sh portainer start
```

#### First-time setup

1. Open **`https://endurance:9443`** (or `http://192.168.1.50:9000` from localhost) in a browser.
2. Create the **admin account**. Choose a strong password — this is the only authentication layer.
3. On the **Environment** screen, select **Docker** and click **Connect**. Portainer auto-detects the local daemon via the mounted socket.

#### Access URLs

| URL | Notes |
|-----|-------|
| `https://endurance:9443` | HTTPS (self-signed cert) — recommended for LAN access |
| `http://localhost:9000` | HTTP — localhost only; not exposed to the LAN |

Accept the self-signed certificate warning in the browser, or replace it with a certificate from your LAN CA if desired.

#### Security notes

- Port `9000` is bound to `127.0.0.1` only; LAN devices must use `:9443`.
- The Docker socket is mounted **read-only** (`:ro`). All management operations go through the Portainer API, which correctly enforces its own access controls.
- `no-new-privileges` and `cap_drop: ALL` are set in the Compose config for defence-in-depth.
- Change the default admin password immediately; do not reuse passwords from other services.

#### Verify

```bash
bash provisioning/scripts/module.sh portainer status
curl -sf http://localhost:9000/api/status | jq .
```

---

### 5.3 Pi-hole

#### Purpose

Pi-hole acts as a DNS sinkhole for the entire LAN, blocking ads, tracking domains, and malware at the DNS level — no per-device software required.

#### Prerequisites

- The server's **static LAN IP address** (e.g. `192.168.1.50`).
- A chosen **admin password** for the Pi-hole web UI.
- `systemd-resolved` stub listener must be disabled if it occupies port 53 (see below).

#### Disable systemd-resolved stub (if active)

```bash
sudo systemctl disable --now systemd-resolved
sudo rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

Verify port 53 is free:

```bash
sudo ss -tulpn | grep ':53'   # should return no output
```

#### Configure

```bash
bash provisioning/scripts/module.sh pihole install
nano modules/pihole/.env
```

`modules/pihole/.env`:

```dotenv
TZ=Europe/Madrid
WEBPASSWORD=ChangeMeNow!
PIHOLE_DNS_=1.1.1.1;1.0.0.1
FTLCONF_LOCAL_IPV4=192.168.1.50
```

| Variable | Required | Description |
|----------|----------|-------------|
| `WEBPASSWORD` | Yes | Admin UI password — **change before starting** |
| `FTLCONF_LOCAL_IPV4` | Yes | Server LAN IP (used in Pi-hole's self-referencing DNS records) |
| `TZ` | No | Timezone (e.g. `Europe/London`) |
| `PIHOLE_DNS_` | No | Upstream DNS servers separated by `;` |

#### Start

```bash
bash provisioning/scripts/module.sh pihole start
```

#### Configure LAN DNS

**Router (recommended):** Set the primary DNS server distributed by DHCP to `192.168.1.50`. All LAN devices will automatically use Pi-hole without any per-device configuration.

**Per-device (alternative):**
- Primary DNS: `192.168.1.50`
- Secondary DNS: `1.1.1.1` (fallback if Pi-hole is down)

#### Access URLs

| URL | Description |
|-----|-------------|
| `http://endurance:8080/admin` | Admin dashboard |
| `http://192.168.1.50:8080/admin` | Same, using IP (works before DNS propagates) |

#### Verify

```bash
# Container health
bash provisioning/scripts/module.sh pihole status

# DNS resolution through Pi-hole
dig @192.168.1.50 example.com +short

# Confirm a known ad domain is blocked
dig @192.168.1.50 doubleclick.net +short   # should return 0.0.0.0
```

---

### 5.4 MagicMirror²

#### Purpose

MagicMirror² serves a browser-based smart dashboard showing the current time, weather, iCloud calendar events, and news headlines. Access it from any browser or a wall-mounted tablet on the LAN.

#### Prerequisites

- A free **OpenWeatherMap API key** — sign up at [openweathermap.org](https://openweathermap.org/api).
- Your **iCloud public calendar ICS URL** (optional, but recommended).

#### Obtain the iCloud calendar URL

1. Open the **Calendar** app on macOS (or iCloud.com → Calendar).
2. Right-click a calendar → **Share Calendar…** (macOS) or click the share icon (web).
3. Enable **Public Calendar**.
4. Copy the URL. It looks like:  
   `https://p123-caldav.icloud.com/published/2/MTIzNDU2Nzg5...`

#### Configure

Edit `modules/magicmirror/config/config.js` directly — there is no `.env` for the MagicMirror module configuration:

```javascript
// Calendar — replace the placeholder URL
{
  module: "calendar",
  config: {
    calendars: [
      {
        fetchInterval: 300000,
        symbol: "calendar-check",
        url: "https://p123-caldav.icloud.com/published/2/YOUR_CALENDAR_ID"
      }
    ]
  }
}

// Weather — replace API key and coordinates
{
  module: "weather",
  config: {
    weatherProvider: "openweathermap",
    type: "current",
    apiKey: "YOUR_OPENWEATHERMAP_API_KEY",
    lat: 43.3623,    // your latitude
    lon: -8.4115     // your longitude
  }
}
```

If you need to configure the timezone or port, create `modules/magicmirror/.env`:

```dotenv
TZ=Europe/Madrid
```

#### Start

```bash
bash provisioning/scripts/module.sh magicmirror install
bash provisioning/scripts/module.sh magicmirror start
```

#### Access

| URL | Description |
|-----|-------------|
| `http://endurance:8181` | Dashboard — open in a full-screen browser |
| `http://192.168.1.50:8181` | Same, using IP |

Open in a tablet or monitor browser. For a kiosk setup on Chromium:

```bash
chromium-browser --kiosk --noerrdialogs http://endurance:8181
```

#### Verify

```bash
bash provisioning/scripts/module.sh magicmirror status
curl -sf http://localhost:8181/ | head -5   # should return HTML
```

After a configuration change, restart without rebuilding:

```bash
bash provisioning/scripts/module.sh magicmirror restart
```

---

### 5.5 Backend Applications

#### Module structure

Every backend service follows the same layout as `modules/backend-template/`:

```
modules/<service-name>/
├── docker-compose.yml     # Compose config — exposes port, sets networks
├── Dockerfile             # Multi-stage Python build
├── .env.example           # Environment variable template
├── .env                   # Active config (created from .env.example)
├── main.py                # FastAPI application
├── requirements.txt       # Python dependencies
└── tests/
    └── test_main.py       # Pytest suite
```

The image is built locally on `endurance` by the CI/CD workflow; there is no registry push.

#### Run the backend-template locally

```bash
bash provisioning/scripts/module.sh backend-template install
nano modules/backend-template/.env
bash provisioning/scripts/module.sh backend-template start
```

`modules/backend-template/.env`:

```dotenv
APP_NAME=backend-template
APP_ENV=production
APP_PORT=8000
LOG_LEVEL=info
DATABASE_URL=sqlite:///./data/app.db
```

Verify:

```bash
curl http://localhost:8000/health
# {"status":"healthy","service":"backend-template","timestamp":"..."}

curl http://localhost:8000/docs   # Swagger UI in browser
```

#### CI/CD deployment flow

When a commit is pushed to `main` and touches files under `modules/backend-template/` or `.github/workflows/backend-template.yml`, GitHub Actions runs the following pipeline:

```
push to main
    │
    ▼
[ubuntu-latest]
  ├── Checkout
  ├── Set up Python 3.12
  └── Run pytest tests/

    │ tests pass
    ▼
[self-hosted, linux, endurance]   ← runs on endurance via GH runner
  ├── Checkout
  ├── Create .env from GitHub Secrets
  ├── docker compose build --no-cache
  ├── docker compose up -d --force-recreate --remove-orphans
  └── Poll GET /health until 200 (30 attempts, 5 s interval)
```

Required GitHub Secrets (repository → Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `DATABASE_URL` | Database connection string (optional; defaults to SQLite) |

Any additional secrets that a specific backend needs should be added here and referenced in the workflow's `Create .env` step.

#### Create a new backend service

```bash
# 1. Copy the template
cp -r modules/backend-template modules/my-service

# 2. Rename service in Compose
sed -i 's/backend-template/my-service/g' modules/my-service/docker-compose.yml

# 3. Update port in .env.example
# Edit APP_PORT to an unused port, e.g. 8001

# 4. Implement your API in main.py

# 5. Copy and adapt the workflow
cp ci/backend-template.yml .github/workflows/my-service.yml
# Update MODULE_NAME and MODULE_PATH in the workflow file

# 6. Install and start manually for initial test
bash provisioning/scripts/module.sh my-service install
bash provisioning/scripts/module.sh my-service start
```

#### Verify a CI/CD deployment

```bash
# After a push triggers the workflow:
# 1. Check the Actions tab on GitHub for workflow status
# 2. On endurance — confirm the container was recreated
docker ps --filter name=endurance-my-service

# 3. Health check
curl http://localhost:8000/health
```

---

## 6. TUI Installer

The TUI provides a fully interactive console for managing the entire platform without memorising CLI arguments.

#### Launch

```bash
bash tui/endurance_tui.sh
```

The script auto-escalates to `sudo` when a privileged operation (provisioning) is required. All other module operations run as the current user.

#### Main menu

```
  Main Menu

    1  ⚙  Base system provisioning
    2  📦 Module management
    3  📊 System health dashboard
    4  ⚡ Quick actions
    5  ℹ  About
    q  ▸  Quit
```

#### Menu 1 — Base system provisioning

Displays a summary of what will be run and asks for confirmation before invoking `provisioning/scripts/provision.sh`. Displays step-by-step progress with colour-coded output.

#### Menu 2 — Module management

Lists all modules with live running/stopped status indicators. Selecting a module opens a per-module action menu:

| Action | Description |
|--------|-------------|
| `1` Install | Copies `.env.example` → `.env`; runs `install.sh` if present |
| `2` Start | Runs `docker compose up -d` (with optional `pre-start.sh` hook) |
| `3` Stop | Stops containers (preserves volumes) |
| `4` Restart | Restarts all containers in the Compose project |
| `5` Update | `docker compose pull` then `up -d --force-recreate` |
| `6` Status | Shows `docker compose ps` output |
| `7` Logs | Tails the last 50 log lines (`-f`) |
| `8` Remove | `docker compose down -v` (destroys containers **and** volumes — prompted) |
| `9` Edit `.env` | Opens `.env` in `$EDITOR` (defaults to `nano`) |

#### Menu 3 — System health dashboard

Displays:
- Hostname, uptime, kernel version, load averages
- Memory usage (`free -h`)
- Disk usage (`df -h /`)
- Docker version and container counts
- Per-module running/stopped status icons

#### Menu 4 — Quick actions

| Option | Description |
|--------|-------------|
| `1` Start ALL | Iterates all modules and calls `start` |
| `2` Stop ALL | Iterates all modules and calls `stop` |
| `3` Update ALL | Pulls + recreates all module containers |
| `4` Docker prune | `docker system prune -f` (prompted) |
| `5` Show containers | `docker ps` table |

---

### Typical TUI workflows

#### "From zero to everything enabled"

```
Launch TUI → Main Menu
  → 1 (Provisioning) → Confirm → wait for completion → Enter

  → 2 (Modules) → 1 (portainer) → 1 (Install) → edit .env if needed → 2 (Start) → b
  → 2 (Modules) → 2 (pihole)    → 1 (Install) → edit .env (set WEBPASSWORD, IP) → 2 (Start) → b
  → 2 (Modules) → 3 (magicmirror) → 1 (Install) → edit config.js → 2 (Start) → b
  → 2 (Modules) → 4 (cicd-runner) → 1 (Install) → edit .env (token) → 2 (Start) → b
  → 2 (Modules) → 5 (backend-template) → 1 (Install) → 2 (Start) → b

  → 3 (Health) → verify all modules show ✔
```

#### "Enable only Pi-hole and Portainer"

```
Launch TUI → Main Menu
  → 2 (Modules) → 2 (pihole)    → 1 (Install) → edit .env → 2 (Start) → b
  → 2 (Modules) → 1 (portainer) → 1 (Install) → 2 (Start) → b
```

#### "Update a backend after pushing to GitHub"

This is normally handled automatically by CI/CD. To trigger manually from the TUI:

```
Launch TUI → Main Menu
  → 2 (Modules) → 5 (backend-template) → 5 (Update) → b
```

Or directly from the CLI:

```bash
bash provisioning/scripts/module.sh backend-template update
```

---

## 7. Operations and Maintenance

### Start, stop, and restart modules

```bash
# Individual module
bash provisioning/scripts/module.sh <name> start
bash provisioning/scripts/module.sh <name> stop
bash provisioning/scripts/module.sh <name> restart

# All modules at once (via Compose directly)
for m in portainer pihole magicmirror cicd-runner backend-template; do
  bash provisioning/scripts/module.sh "$m" start
done
```

### Check logs

```bash
# Tail 50 lines + follow
bash provisioning/scripts/module.sh <name> logs

# Raw Compose logs for a specific service
cd modules/<name> && docker compose logs --tail=100 -f

# Health status of all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Update images and redeploy

```bash
bash provisioning/scripts/module.sh <name> update
```

This pulls a fresh image (`docker compose pull`) and recreates the container (`docker compose up -d --force-recreate`). For backend services built from a Dockerfile, the update action rebuilds the image from the current source.

### Prune unused Docker resources

```bash
docker system prune -f           # removes stopped containers, dangling images, unused networks
docker image prune -a -f         # removes ALL unused images (use with caution)
docker volume prune -f           # removes unused volumes (use with caution — data loss risk)
```

---

### Troubleshooting

#### CI/CD runner offline

| Step | Command |
|------|---------|
| Check container state | `docker ps --filter name=endurance-gh-runner` |
| Check for auth errors | `bash provisioning/scripts/module.sh cicd-runner logs` |
| Verify token is valid | Re-generate PAT and update `modules/cicd-runner/.env` |
| Restart container | `bash provisioning/scripts/module.sh cicd-runner restart` |

A common cause is token expiry. Regenerate the PAT on GitHub, update `ACCESS_TOKEN` in `.env`, and restart the container.

#### MagicMirror² not accessible

| Check | Command/Action |
|-------|---------------|
| Container running? | `bash provisioning/scripts/module.sh magicmirror status` |
| Port 8181 listening? | `sudo ss -tulpn \| grep 8181` |
| Config syntax error? | `bash provisioning/scripts/module.sh magicmirror logs` — look for JS parse errors |
| UFW blocking? | `sudo ufw status \| grep 8181` |

After fixing a `config.js` syntax error, restart (do not remove):

```bash
bash provisioning/scripts/module.sh magicmirror restart
```

#### Pi-hole DNS not resolving

| Check | Command/Action |
|-------|---------------|
| Container running? | `bash provisioning/scripts/module.sh pihole status` |
| Port 53 bound? | `sudo ss -tulpn \| grep ':53'` |
| Test DNS directly | `dig @192.168.1.50 example.com +short` |
| Check for port conflict | `systemctl status systemd-resolved` — disable if active |
| Container logs | `bash provisioning/scripts/module.sh pihole logs` |

If Pi-hole was initially unreachable and you disabled `systemd-resolved` later, restart the container to rebind port 53:

```bash
bash provisioning/scripts/module.sh pihole restart
```

#### Portainer not reachable

| Check | Command/Action |
|-------|---------------|
| Container running? | `bash provisioning/scripts/module.sh portainer status` |
| HTTPS port open? | `sudo ss -tulpn \| grep 9443` |
| Healthcheck passing? | `docker inspect endurance-portainer \| jq '.[0].State.Health'` |
| API responding? | `curl -sf http://localhost:9000/api/status` |
| UFW rule present? | `sudo ufw status \| grep 9443` |

If the container is unhealthy, check the logs:

```bash
bash provisioning/scripts/module.sh portainer logs
```

---

## 8. Backup Considerations

The following data is stateful and should be included in regular backups. Docker named volumes are stored at `/var/lib/docker/volumes/<volume_name>/_data` and can be backed up with standard tools.

| Service | Volume / Path | Contents |
|---------|--------------|----------|
| Portainer | `portainer_data` | Portainer settings, user accounts, endpoint config |
| Pi-hole | `pihole_config` | Block lists, custom DNS records, groups, settings |
| Pi-hole | `pihole_dnsmasq` | dnsmasq configuration overrides |
| Backend apps | `backend_data` | Per-application persistent data (SQLite, uploads, etc.) |
| MagicMirror² | `modules/magicmirror/config/config.js` | Module configuration (tracked in git) |
| CI/CD runner | `runner_work` | Temporary job workspace — not worth backing up |

### Recommended backup approach

```bash
# Back up a Docker named volume
docker run --rm \
  -v <volume_name>:/source:ro \
  -v /backup:/backup \
  debian:slim \
  tar czf /backup/<volume_name>-$(date +%Y%m%d).tar.gz -C /source .
```

For `config.js` and other tracked configuration files, committing changes to the Git repository is the natural backup mechanism.

Consider scheduling backups via cron:

```bash
# /etc/cron.d/endurance-backup
0 3 * * * root bash /home/<user>/homeserver/provisioning/scripts/backup.sh >> /var/log/endurance-backup.log 2>&1
```

---

*This document covers the endurance platform as implemented in the current repository state. For module-specific deep-dives, refer to the individual docs in the `docs/` directory.*
