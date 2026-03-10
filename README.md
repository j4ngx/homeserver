# Endurance — Home Server Platform

> Modular, Docker-based home server for Debian 13.

Full documentation lives in [docs/README.md](docs/README.md).

## Quick Start

```bash
# 1. Provision the base system
sudo bash provisioning/scripts/provision.sh

# 2. Launch the interactive TUI
bash tui/endurance_tui.sh

# 3. Or manage modules directly
bash provisioning/scripts/module.sh portainer install
bash provisioning/scripts/module.sh portainer start
```

## Modules

| Module | Port | Description |
|--------|------|-------------|
| Portainer | 9443 | Docker management UI |
| Pi-hole | 53 / 8080 | Network-wide ad blocker |
| MagicMirror² | 8181 | Smart display dashboard |
| CI/CD Runner | — | GitHub Actions self-hosted runner |
| Backend Template | 8000 | Reference FastAPI service |

## License

Private — personal home server project.
