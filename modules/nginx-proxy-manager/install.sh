#!/usr/bin/env bash
# =============================================================================
# nginx-proxy-manager/install.sh — Post-install helper
# =============================================================================
# Called automatically by: module.sh nginx-proxy-manager install
# Prints first-run instructions and recommended proxy host configuration.
# =============================================================================

set -Eeuo pipefail

if [[ -t 1 ]]; then
  CYAN='\033[0;36m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'
else
  CYAN='' YELLOW='' GREEN='' BOLD='' NC=''
fi

echo
echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║       Nginx Proxy Manager — First-Run Instructions          ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "  ${BOLD}Admin UI:${NC}  http://endurance:81"
echo -e "  ${BOLD}Default login:${NC}"
echo -e "    Email   : admin@example.com"
echo -e "    Password: changeme"
echo
echo -e "  ${YELLOW}⚠  CHANGE THE PASSWORD IMMEDIATELY ON FIRST LOGIN!${NC}"
echo
echo -e "  ${GREEN}Recommended Proxy Hosts (configure in UI):${NC}"
echo
printf '  %-28s %-12s %-10s %s\n' "Domain" "Forward" "Port" "Notes"
echo -e "  ${CYAN}$(printf '%0.s─' {1..70})${NC}"
printf '  %-28s %-12s %-10s %s\n' "endurance.local"          "endurance"  "9443"  "Portainer (HTTPS passthrough)"
printf '  %-28s %-12s %-10s %s\n' "endurance.local/mirror"   "endurance"  "8181"  "MagicMirror²"
printf '  %-28s %-12s %-10s %s\n' "endurance.local/pihole"   "endurance"  "8080"  "Pi-hole Admin"
printf '  %-28s %-12s %-10s %s\n' "endurance.local/uptime"   "endurance"  "3001"  "Uptime Kuma"
printf '  %-28s %-12s %-10s %s\n' "endurance.local/api"      "endurance"  "8000"  "Backend API"
echo
echo -e "  ${GREEN}DNS — Local domain resolution:${NC}"
echo -e "  Add to your router's DNS or Pi-hole custom DNS:"
echo -e "    ${CYAN}endurance.local → <SERVER_LAN_IP>${NC}"
echo -e "  Or add to each client's /etc/hosts:"
echo -e "    ${CYAN}<SERVER_LAN_IP>  endurance.local${NC}"
echo
echo -e "  ${GREEN}SSL Certificates:${NC}"
echo -e "  • For LAN-only use, create a Self-Signed certificate in NPM."
echo -e "  • For public domains, use Let's Encrypt HTTP-01 or DNS-01 challenge."
echo -e "  • For split-horizon (local domain + real cert), use DNS-01 challenge"
echo -e "    with your DNS provider's API credentials in NPM."
echo
