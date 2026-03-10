# Watchtower

Automatic Docker container image updater for the endurance platform.

## Overview

| Item | Value |
|------|-------|
| Image | `containrrr/watchtower:1.7.1` |
| Schedule | Weekly — Sunday 03:00 AM |
| Network | `endurance_backend` (internal) |
| Excludes | `endurance-portainer`, `endurance-uptime-kuma` |

## How it works

Watchtower polls the Docker daemon every week (configurable). When a container's image has a newer version on the registry, it:

1. Pulls the new image
2. Stops the old container
3. Starts a new container using the same configuration
4. Optionally removes the old image

Rolling restart (`WATCHTOWER_ROLLING_RESTART=true`) ensures containers are updated one at a time to minimise downtime.

## Setup

```bash
bash provisioning/scripts/module.sh watchtower install
# Edit .env to configure schedule and notifications (optional)
bash provisioning/scripts/module.sh watchtower start
```

## Excluded containers

The following containers are **never** auto-updated:

| Container | Reason |
|-----------|--------|
| `endurance-portainer` | Prefer manual upgrades to control UI changes |
| `endurance-uptime-kuma` | Avoid monitoring blind-spots during update |

To exclude additional containers, add their names to `WATCHTOWER_IGNORE_CONTAINERS` in `.env`.

## Notifications

Watchtower uses [Shoutrrr](https://containrrr.dev/shoutrrr/) for notifications. Set `WATCHTOWER_NOTIFICATION_URL` in `.env`:

**Telegram:**
```
telegram://<BOT_TOKEN>@telegram?channels=<CHAT_ID>
```

Leave `WATCHTOWER_NOTIFICATION_URL` empty to disable notifications.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Europe/Madrid` | Timezone for cron schedule evaluation |
| `WATCHTOWER_SCHEDULE` | `0 0 3 * * 0` | Cron expression (includes seconds field) |
| `WATCHTOWER_NOTIFICATION_URL` | _(empty)_ | Shoutrrr notification URL |
| `WATCHTOWER_NOTIFICATIONS_LEVEL` | `info` | Verbosity: `debug`/`info`/`warn`/`error` |
| `WATCHTOWER_LOG_LEVEL` | `info` | Container log level |

## One-shot manual update

Trigger an immediate update check without starting the scheduled service:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower:1.7.1 --run-once
```

## Removal

```bash
bash provisioning/scripts/module.sh watchtower remove
```

Watchtower has no persistent volumes — removal is clean and instant.
