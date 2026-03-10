# Nginx Proxy Manager

Reverse proxy with a web-based GUI and automatic Let's Encrypt SSL certificate management.

## Overview

| Item | Value |
|------|-------|
| Image | `jc21/nginx-proxy-manager:2.12.3` |
| Admin UI | http://endurance:81 |
| HTTP proxy | port 80 |
| HTTPS proxy | port 443 |
| Network | `endurance_frontend` |
| Data volumes | `npm_data`, `npm_letsencrypt` |

## Default credentials

```
Email:    admin@example.com
Password: changeme
```

> ⚠️ **Change the password immediately on first login.**

## Setup

### 1. Install and start

```bash
bash provisioning/scripts/module.sh nginx-proxy-manager install
bash provisioning/scripts/module.sh nginx-proxy-manager start
```

### 2. First login

Open http://endurance:81, log in, and change your password.

### 3. Configure proxy hosts

Navigate to **Proxy Hosts → Add Proxy Host** for each service:

| Domain | Forward Hostname | Forward Port | SSL |
|--------|-----------------|--------------|-----|
| `endurance.local` | `endurance` | `9443` | HTTPS passthrough |
| `endurance.local` *(path: /mirror)* | `endurance` | `8181` | Self-signed / None |
| `endurance.local` *(path: /pihole)* | `endurance` | `8080` | Self-signed / None |
| `endurance.local` *(path: /uptime)* | `endurance` | `3001` | Self-signed / None |
| `endurance.local` *(path: /api)* | `endurance` | `8000` | Self-signed / None |

> NPM does not natively support path-based routing to *separate* backends in the same way a full Nginx config does. For `/mirror`, `/pihole` etc., either:
> - Use **subdomains** (`mirror.endurance.local`, `pihole.endurance.local`) — recommended, simpler.
> - Use a custom Nginx config snippet with `location /mirror { proxy_pass http://endurance:8181; }`.

### 4. DNS — local domain resolution

Add to your **router DNS** or **Pi-hole custom DNS records**:

```
endurance.local → <SERVER_LAN_IP>
```

Or add to each client machine's `/etc/hosts`:

```
192.168.1.50  endurance.local
```

### 5. SSL certificates

**Option A — Self-signed (LAN only, fastest)**
In NPM: **SSL Certificates → Add SSL Certificate → Custom** → generate a self-signed cert.

**Option B — Let's Encrypt (public domain)**
Requires port 80/443 reachable from the internet and a public domain pointing to your server.

**Option C — Let's Encrypt DNS-01 challenge (local domain + real cert)**
Configure your DNS provider's API credentials in NPM under **SSL Certificates → Add Let's Encrypt Certificate → DNS Challenge**.

## Recommended architecture

```
Internet / LAN
       │
       ▼
 ┌─────────────────────────────────────────┐
 │   Nginx Proxy Manager  :80/:443         │
 │   Admin UI             :81              │
 └─────────────┬───────────────────────────┘
               │  endurance_frontend network
       ┌───────┼────────────────┐
       ▼       ▼                ▼
  Portainer  MagicMirror    Pi-hole
  :9443      :8181          :8080
             Uptime Kuma    Backend API
             :3001          :8000
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Europe/Madrid` | Timezone |
| `DISABLE_IPV6` | `false` | Set `true` if host has no IPv6 |

## Proxy-ready docker-compose snippet

When adding new backend services that should be proxied, connect them to `endurance_frontend`:

```yaml
services:
  my-service:
    image: my-image:tag
    networks:
      - endurance_frontend

networks:
  endurance_frontend:
    external: true
```

Then add a Proxy Host in NPM pointing to `my-service` (container name) on the appropriate port.

## Removal

```bash
bash provisioning/scripts/module.sh nginx-proxy-manager remove
```

> ⚠️ This removes SSL certificates and all proxy configuration stored in volumes.
