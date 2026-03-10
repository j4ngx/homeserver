# Changelog

All notable changes to the Endurance home server project are documented here.

## [1.1.0] — 2026-03-10 — Hardening & Review Pass

### provisioning/

#### `provisioning/scripts/provision.sh`
- **Added** UFW firewall configuration step (default deny incoming, allow SSH + module ports)
- **Added** `configure_ufw()` function called after `create_module_dirs()`

#### `provisioning/scripts/module.sh`
- **Fixed** `do_stop` now uses `docker compose stop` (preserves containers) instead of `docker compose down` (which destroyed them)
- **Fixed** `do_restart` now uses `docker compose restart` instead of `down + up -d` (faster, preserves state)

### modules/

#### All modules (Docker Compose hardening)
- **Added** `security_opt: no-new-privileges:true` to all services
- **Added** `cap_drop: [ALL]` to all services (with selective `cap_add` where needed)
- **Changed** All images pinned to specific versions instead of `:latest`

#### `modules/portainer/`
- **Changed** image `portainer/portainer-ce:latest` → `portainer/portainer-ce:2.27.3`
- **Added** healthcheck (wget to `/api/status`)
- **Changed** HTTP port (9000) bound to `127.0.0.1` only — use HTTPS (9443) for LAN access

#### `modules/pihole/`
- **Changed** image `pihole/pihole:latest` → `pihole/pihole:2024.07.0`
- **Added** healthcheck (`dig +norecurse @127.0.0.1 pi.hole`)
- **Added** granular `cap_add` (NET_ADMIN, NET_RAW, NET_BIND_SERVICE, CHOWN, DAC_OVERRIDE, FOWNER, SETGID, SETUID) instead of just NET_ADMIN

#### `modules/magicmirror/`
- **Changed** image `karsten13/magicmirror:latest` → `karsten13/magicmirror:v2.30.0`
- **Added** healthcheck (`curl -f http://localhost:8080`)
- **Changed** bind mounts now `:ro` (config, modules, css are read-only inside container)
- **Added** `tmpfs: /tmp` for ephemeral writes

#### `modules/cicd-runner/`
- **Changed** image `myoung34/github-runner:latest` → `myoung34/github-runner:2.321.0`
- **Added** inline comment documenting Docker socket security implications

#### `modules/backend-template/`
- **Added** `read_only: true` filesystem with `tmpfs: /tmp`
- **Fixed** `tests/test_main.py` — broken assertion (`data["status"] is None`) replaced with correct check for `service` field

#### `modules/cicd-runner/install-native.sh`
- **Fixed** `local tarball=...` used outside a function (bash syntax error in strict mode)

### ci/

- **Added** `.github/workflows/backend-template.yml` — authoritative CI/CD workflow
- **Added** `.github/workflows/healthcheck.yml` — authoritative health check workflow
- **Fixed** GHA `secrets.DATABASE_URL || 'fallback'` syntax (doesn't work in Actions) — replaced with grep-based fallback
- **Fixed** healthcheck workflow now **fails** if any module is unreachable (was silent before)
- **Changed** `ci/backend-template.yml` and `ci/healthcheck.yml` now marked as reference templates, pointing to `.github/workflows/`

### tui/

#### `tui/endurance_tui.sh`
- **Added** confirmation prompt before "Remove" module action (destructive)
- **Added** confirmation prompts before "Start ALL", "Stop ALL", "Update ALL" quick actions
- **Improved** provisioning menu: detects if running as root, avoids redundant `sudo`

### docs/

- **Fixed** `portainer.md` — image tag `lts` → `2.27.3`, updated security notes (`:ro` socket, bound HTTP to localhost)
- **Fixed** `cicd-runner.md` — network `endurance_frontend` → `endurance_backend`, image tag to pinned version, added Docker socket security warning
- **Fixed** `pihole.md` — image tag to pinned version
- **Fixed** `magicmirror.md` — image tag to pinned version
- **Fixed** `backend-template.md` — `APP_NAME` default `endurance-backend` → `backend-template`, removed nonexistent `WORKERS` env var
- **Fixed** `docs/README.md` — corrected action table (`stop` preserves containers, `remove` is destructive), added `.github/workflows/` to project structure, added UFW to provisioning table, updated workflow instructions
- **Added** Root `README.md` pointing to full docs

### Repository

- **Added** `.gitignore` (excludes `.env`, `__pycache__`, IDE files, logs, data)
- **Added** `.github/workflows/` directory

---

## Remaining TODOs / Open Questions

### Assumptions Made
- **LAN IP `192.168.1.50`** — Used as default in Pi-hole, docs, and UFW. Adjust `SERVER_IP` in Pi-hole `.env` for your network.
- **Timezone `Europe/Madrid`** — Default in all modules. Change `TZ` in each module's `.env`.
- **Image versions** — Pinned to versions available at time of review. Update periodically.
- **UFW ports** — Opened for all module default ports. If you don't use a module, remove its UFW rule.

### Optional Next Steps (Not Blocking)
1. **Reverse proxy (Traefik/Caddy)** — Expose all services through a single HTTPS entry point with automatic Let's Encrypt certs. Would replace per-service port exposure.
2. **Automated backups** — Cron job to export Docker volumes and config to an external drive or remote storage (e.g., `restic`, `borgbackup`).
3. **Monitoring stack** — Add Prometheus + Grafana module for metrics, or use Uptime Kuma for lightweight service monitoring.
4. **Log aggregation** — Centralize container logs with Loki or a simple Dozzle container.
5. **Secrets management** — Consider using Docker secrets or a password manager CLI (e.g., `pass`, `op`) instead of `.env` files.
6. **Watchtower** — Optional module for automatic container image updates with notifications.
7. **DNS-over-HTTPS** — Configure Pi-hole upstream to use DoH/DoT for encrypted DNS queries.
8. **Fail2ban rules** — Add custom Fail2ban jails for Portainer, Pi-hole web UI, and SSH.

### Breaking Changes
- **`module.sh stop`** now uses `docker compose stop` instead of `docker compose down`. Containers are preserved (not removed). Use `module.sh remove` to fully tear down a module.
- **Portainer HTTP (9000)** is now bound to `127.0.0.1` only. Use HTTPS port 9443 for LAN access, or edit the compose file to re-expose 9000.
