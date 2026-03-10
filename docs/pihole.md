# Pi-hole — Network-Wide Ad Blocker

Pi-hole acts as a DNS sinkhole, blocking ads and trackers for every device on the LAN without requiring per-device configuration.

## Quick Reference

| Property | Value |
|----------|-------|
| Image | `pihole/pihole:2024.07.0` |
| DNS Port | 53 (TCP + UDP) |
| Web UI Port | 8080 |
| Networks | `endurance_frontend` |
| Volumes | `pihole_config`, `pihole_dnsmasq` |

## Installation

```bash
# 1. Install (creates .env from template)
bash provisioning/scripts/module.sh pihole install

# 2. Edit configuration
nano modules/pihole/.env

# 3. Start
bash provisioning/scripts/module.sh pihole start
```

## Configuration

Edit `modules/pihole/.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Europe/Madrid` | Timezone |
| `WEBPASSWORD` | `changeme` | Web UI admin password |
| `PIHOLE_DNS_` | `1.1.1.1;1.0.0.1` | Upstream DNS servers |
| `FTLCONF_LOCAL_IPV4` | `192.168.1.50` | Server's LAN IP |
| `WEBUI_PORT` | `8080` | Web UI port |

**Important:** Change `WEBPASSWORD` before starting the container.

## LAN DNS Configuration

To use Pi-hole for the entire network, configure your router's DHCP settings to distribute `192.168.1.50` as the primary DNS server.

### Per-Device (Alternative)

Set the DNS server on individual devices:
- **Primary DNS:** `192.168.1.50`
- **Secondary DNS:** `1.1.1.1` (fallback if Pi-hole is down)

## Access

| URL | Description |
|-----|-------------|
| `http://192.168.1.50:8080/admin` | Web admin dashboard |

## Management

```bash
# Check status
bash provisioning/scripts/module.sh pihole status

# View logs
bash provisioning/scripts/module.sh pihole logs

# Update to latest image
bash provisioning/scripts/module.sh pihole update

# Stop
bash provisioning/scripts/module.sh pihole stop

# Remove
bash provisioning/scripts/module.sh pihole remove
```

## Updating Block Lists

1. Open the Pi-hole web UI.
2. Go to **Group Management → Adlists**.
3. Add additional block list URLs.
4. Go to **Tools → Update Gravity** to apply.

## Troubleshooting

### Port 53 Already in Use

If `systemd-resolved` is using port 53:

```bash
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo rm /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

Then restart the Pi-hole container.

### DNS Not Resolving

1. Check the container is running: `docker compose -f modules/pihole/docker-compose.yml ps`
2. Check logs: `docker compose -f modules/pihole/docker-compose.yml logs`
3. Test DNS directly: `dig @192.168.1.50 google.com`
