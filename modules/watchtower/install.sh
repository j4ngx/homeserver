#!/usr/bin/env bash
# =============================================================================
# watchtower/install.sh — Post-install helper
# =============================================================================
# Called automatically by: module.sh watchtower install
# =============================================================================

set -Eeuo pipefail

if [[ -t 1 ]]; then
  CYAN='\033[0;36m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
else
  CYAN='' YELLOW='' GREEN='' NC=''
fi

echo
echo -e "${CYAN}  ╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║          Watchtower — Setup Notes                ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════╝${NC}"
echo
echo -e "  ${GREEN}Schedule:${NC} Weekly — Sunday 03:00 AM (configurable via WATCHTOWER_SCHEDULE)"
echo
echo -e "  ${GREEN}Excluded:${NC} Portainer + Uptime Kuma (update manually)"
echo
echo -e "  ${GREEN}Notifications:${NC} Set WATCHTOWER_NOTIFICATION_URL in .env"
echo -e "  Use Shoutrrr Telegram format:"
echo -e "    ${CYAN}telegram://<BOT_TOKEN>@telegram?channels=<CHAT_ID>${NC}"
echo
echo -e "  To trigger an immediate one-shot update check:"
echo -e "    ${CYAN}docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\${NC}"
echo -e "    ${CYAN}    containrrr/watchtower:1.7.1 --run-once${NC}"
echo
echo -e "  ${YELLOW}⚠${NC}  Watchtower uses rolling restarts to minimise downtime."
echo -e "     Stateful services (Pi-hole, databases) may have brief interruptions."
echo
