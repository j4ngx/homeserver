# Portainer — Docker Management UI

Portainer CE provides a web-based interface for managing Docker containers, images, networks, and volumes on the endurance server.

## Quick Reference

| Property | Value |
|----------|-------|
| Image | `portainer/portainer-ce:2.27.3` |
| HTTP Port | 9000 |
| HTTPS Port | 9443 |
| Network | `endurance_frontend` |
| Data Volume | `portainer_data` |

## Installation

```bash
bash provisioning/scripts/module.sh portainer install
bash provisioning/scripts/module.sh portainer start
```

## Configuration

No `.env` file is required. Portainer runs with sensible defaults.

The Docker socket is mounted read-only (`/var/run/docker.sock:/var/run/docker.sock:ro`) to allow container management without exposing write access at the socket level.

## First-Time Setup

1. Open `http://<server-ip>:9000` in a browser.
2. Create an admin account (username + password).
3. Select **Docker** as the environment type.
4. Click **Connect** — Portainer will auto-detect the local Docker daemon.

## Access

| URL | Description |
|-----|-------------|
| `http://192.168.1.50:9000` | HTTP dashboard |
| `https://192.168.1.50:9443` | HTTPS dashboard (self-signed cert) |

## Management

```bash
# Check status
bash provisioning/scripts/module.sh portainer status

# View logs
bash provisioning/scripts/module.sh portainer logs

# Update to latest image
bash provisioning/scripts/module.sh portainer update

# Stop
bash provisioning/scripts/module.sh portainer stop

# Remove (stops containers and deletes volumes)
bash provisioning/scripts/module.sh portainer remove
```

## Security Notes

- Change the default admin password immediately after first login.
- Consider restricting access to port 9443 via UFW to your LAN only.
- The Docker socket is mounted **read-only** (`:ro`), which prevents direct writes at the socket level. However, the Docker API itself still allows full container management — secure the web UI appropriately.
- The HTTP port (9000) is bound to `127.0.0.1` only. Use HTTPS (9443) for LAN access.
- `security_opt: no-new-privileges` and `cap_drop: ALL` are applied for defense-in-depth.
