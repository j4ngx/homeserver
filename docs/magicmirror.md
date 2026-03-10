# MagicMirror² — Smart Display Dashboard

MagicMirror² displays real-time information (clock, calendar, weather, news) on a screen or tablet connected to the endurance server.

## Quick Reference

| Property | Value |
|----------|-------|
| Image | `karsten13/magicmirror:v2.30.0` |
| Web Port | 8181 |
| Network | `endurance_frontend` |
| Config | `modules/magicmirror/config/config.js` |
| Custom CSS | `modules/magicmirror/css/custom.css` |
| Extra Modules | `modules/magicmirror/modules/` |

## Installation

```bash
# 1. Install (creates .env from template)
bash provisioning/scripts/module.sh magicmirror install

# 2. Configure
nano modules/magicmirror/config/config.js

# 3. Start
bash provisioning/scripts/module.sh magicmirror start
```

## Configuration

### config.js

Edit `modules/magicmirror/config/config.js` to customize modules. Key sections to update:

#### Calendar (iCloud)

Replace the placeholder ICS URL with your actual iCloud calendar URL:

```javascript
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
```

**To get your iCloud calendar URL:**
1. Open Calendar app on macOS.
2. Right-click the calendar → **Share Calendar…**
3. Check **Public Calendar** and copy the URL.

#### Weather (OpenWeatherMap)

1. Create a free account at [openweathermap.org](https://openweathermap.org/).
2. Generate an API key.
3. Update the config:

```javascript
{
  module: "weather",
  config: {
    weatherProvider: "openweathermap",
    apiKey: "YOUR_OPENWEATHERMAP_API_KEY",
    lat: 43.3623,
    lon: -8.4115
  }
}
```

### .env

Edit `modules/magicmirror/.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Europe/Madrid` | Timezone |
| `MM_PORT` | `8181` | Web UI port |

### Custom CSS

Edit `modules/magicmirror/css/custom.css` to override the default MagicMirror styles.

### Third-Party Modules

Place additional MagicMirror modules in `modules/magicmirror/modules/`. They will be mounted into the container at `/opt/magic_mirror/modules`.

## Access

| URL | Description |
|-----|-------------|
| `http://192.168.1.50:8181` | MagicMirror dashboard |

Open this URL in a full-screen browser (kiosk mode) on the target display device.

## Management

```bash
# Check status
bash provisioning/scripts/module.sh magicmirror status

# View logs
bash provisioning/scripts/module.sh magicmirror logs

# Restart (after config changes)
bash provisioning/scripts/module.sh magicmirror restart

# Update to latest image
bash provisioning/scripts/module.sh magicmirror update

# Stop
bash provisioning/scripts/module.sh magicmirror stop

# Remove
bash provisioning/scripts/module.sh magicmirror remove
```

## Kiosk Mode (Tablet/Screen)

For a dedicated display, configure the device's browser to open `http://192.168.1.50:8181` in full-screen mode on boot.

### Chromium Kiosk (Debian)

```bash
chromium-browser --kiosk --noerrdialogs --disable-translate \
  --no-first-run --fast --fast-start --disable-infobars \
  http://192.168.1.50:8181
```
