#!/usr/bin/env bash
# =============================================================================
# uptime-kuma/install.sh — Post-install helper
# =============================================================================
# Called automatically by: module.sh uptime-kuma install
# Prints setup instructions for Telegram notifications.
# =============================================================================

set -Eeuo pipefail

if [[ -t 1 ]]; then
  CYAN='\033[0;36m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
else
  CYAN='' YELLOW='' GREEN='' NC=''
fi

echo
echo -e "${CYAN}  ╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║          Uptime Kuma — Setup Notes               ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════╝${NC}"
echo
echo -e "  ${GREEN}1.${NC} Open http://endurance:3001 and create your admin account."
echo
echo -e "  ${GREEN}2.${NC} Add monitors for each service:"
echo -e "     ${CYAN}•${NC} Portainer HTTPS  → https://endurance:9443"
echo -e "     ${CYAN}•${NC} Pi-hole Web UI   → http://endurance:8080/admin"
echo -e "     ${CYAN}•${NC} MagicMirror²     → http://endurance:8181"
echo -e "     ${CYAN}•${NC} CI/CD Runner     → Docker container: endurance-gh-runner"
echo -e "     ${CYAN}•${NC} Backend API      → http://endurance:8000/health"
echo -e "     ${CYAN}•${NC} NPM Proxy UI     → http://endurance:81"
echo -e "     ${CYAN}•${NC} Watchtower       → Docker container: endurance-watchtower"
echo
echo -e "  ${GREEN}3.${NC} Add Telegram notification in Settings → Notifications:"
echo -e "     Bot Token : \$(grep TELEGRAM_BOT_TOKEN .env | cut -d= -f2)"
echo -e "     Chat ID   : \$(grep TELEGRAM_CHAT_ID   .env | cut -d= -f2)"
echo
echo -e "  ${YELLOW}⚠${NC}  Edit .env with your real Telegram credentials before starting."
echo
