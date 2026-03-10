#!/usr/bin/env bash
# =============================================================================
# Endurance TUI — Interactive server management console
# =============================================================================
# Professional TUI for managing the endurance home server platform.
# Integrates with the GLaDOS-style TUI library for consistent UX.
#
# Features:
#   • Base system provisioning
#   • Module management (install/start/stop/status/remove)
#   • Per-module configuration
#   • System health dashboard
#   • Backup and maintenance
#
# Target: Debian 13 · Hostname: endurance
# =============================================================================

set -Eeuo pipefail

###############################################################################
# Resolve paths
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULES_DIR="${PROJECT_ROOT}/modules"
PROVISION_DIR="${PROJECT_ROOT}/provisioning/scripts"
LIB_DIR="${SCRIPT_DIR}/lib"

###############################################################################
# Source TUI library
###############################################################################

if [[ -f "${LIB_DIR}/endurance_tui_lib.sh" ]]; then
  # shellcheck source=/dev/null
  source "${LIB_DIR}/endurance_tui_lib.sh"
else
  echo "FATAL: TUI library not found at ${LIB_DIR}/endurance_tui_lib.sh"
  exit 1
fi

###############################################################################
# Global state
###############################################################################

readonly ENDURANCE_VERSION="1.2.0"
readonly ENDURANCE_NAME="Endurance Server Manager"

# Module registry — name, description, port, compose dir
declare -A MODULE_DESC=(
  [portainer]="Docker management UI"
  [pihole]="Network-wide ad blocker"
  [magicmirror]="Smart display dashboard"
  [cicd-runner]="GitHub Actions self-hosted runner"
  [backend-template]="Reference backend API service"
  [uptime-kuma]="Service monitoring & alerting"
  [watchtower]="Automatic container updater"
  [nginx-proxy-manager]="Reverse proxy + Let's Encrypt SSL"
)

declare -A MODULE_PORT=(
  [portainer]="9000/9443"
  [pihole]="53/8080"
  [magicmirror]="8181"
  [cicd-runner]="—"
  [backend-template]="8000"
  [uptime-kuma]="3001"
  [watchtower]="—"
  [nginx-proxy-manager]="80/443/81"
)

###############################################################################
# Banner
###############################################################################

print_banner() {
  clear 2>/dev/null || true

  local -a logo=(
    "   ███████╗███╗   ██╗██████╗ ██╗   ██╗██████╗  █████╗ ███╗   ██╗ ██████╗███████╗"
    "   ██╔════╝████╗  ██║██╔══██╗██║   ██║██╔══██╗██╔══██╗████╗  ██║██╔════╝██╔════╝"
    "   █████╗  ██╔██╗ ██║██║  ██║██║   ██║██████╔╝███████║██╔██╗ ██║██║     █████╗  "
    "   ██╔══╝  ██║╚██╗██║██║  ██║██║   ██║██╔══██╗██╔══██║██║╚██╗██║██║     ██╔══╝  "
    "   ███████╗██║ ╚████║██████╔╝╚██████╔╝██║  ██║██║  ██║██║ ╚████║╚██████╗███████╗"
    "   ╚══════╝╚═╝  ╚═══╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝"
  )

  local -a grad=(
    '\033[38;5;39m'    # Electric blue
    '\033[38;5;38m'
    '\033[38;5;37m'
    '\033[38;5;36m'
    '\033[38;5;35m'
    '\033[38;5;34m'    # Green-teal
  )

  echo
  local i
  for i in "${!logo[@]}"; do
    printf '%b%s%b\n' "${grad[$i]}" "${logo[$i]}" "$TUI_RESET"
  done

  echo
  tui_divider "single"
  printf '  %b%s Home Server Platform%b  %bv%s%b    %b%s%b\n' \
    "$TUI_BOLD" "$ICON_ROCKET" "$TUI_RESET" \
    "$TUI_MUTED" "$ENDURANCE_VERSION" "$TUI_RESET" \
    "$TUI_DIM" "$(date '+%Y-%m-%d %H:%M')" "$TUI_RESET"
  tui_divider "single"
  echo
}

###############################################################################
# Module status helper
###############################################################################

module_is_running() {
  local name="$1"
  local module_dir="${MODULES_DIR}/${name}"

  if [[ ! -f "${module_dir}/docker-compose.yml" ]]; then
    return 1
  fi

  local running
  running="$(cd "$module_dir" && docker compose ps --status running -q 2>/dev/null | wc -l)"
  (( running > 0 ))
}

module_status_icon() {
  local name="$1"
  if module_is_running "$name"; then
    printf '%b●%b' "$TUI_SUCCESS" "$TUI_RESET"
  else
    printf '%b○%b' "$TUI_MUTED" "$TUI_RESET"
  fi
}

###############################################################################
# Main menu
###############################################################################

main_menu() {
  while true; do
    print_banner

    # Gather module status
    echo -e "  ${TUI_BOLD}${TUI_WHITE}Module Status${TUI_RESET}"
    tui_divider "dots"

    local name
    for name in portainer pihole magicmirror cicd-runner backend-template uptime-kuma watchtower nginx-proxy-manager; do
      local icon
      icon="$(module_status_icon "$name")"
      local port="${MODULE_PORT[$name]}"
      local desc="${MODULE_DESC[$name]}"
      printf '    %b  %-24s %b%-34s%b  %b:%s%b\n' \
        "$icon" "$name" \
        "$TUI_MUTED" "$desc" "$TUI_RESET" \
        "$TUI_DIM" "$port" "$TUI_RESET"
    done

    echo
    tui_divider "single"
    echo

    echo -e "  ${TUI_BOLD}${TUI_WHITE}Main Menu${TUI_RESET}"
    echo
    echo -e "    ${TUI_ACCENT2}1${TUI_RESET}  ${ICON_GEAR}  Base system provisioning"
    echo -e "    ${TUI_ACCENT2}2${TUI_RESET}  ${ICON_PACKAGE}  Module management"
    echo -e "    ${TUI_ACCENT2}3${TUI_RESET}  ${ICON_CHART}  System health dashboard"
    echo -e "    ${TUI_ACCENT2}4${TUI_RESET}  ${ICON_BOLT}  Quick actions"
    echo -e "    ${TUI_ACCENT2}5${TUI_RESET}  ${ICON_INFO}  About"
    echo -e "    ${TUI_ACCENT2}q${TUI_RESET}  ${ICON_ARROW}  Quit"
    echo

    local choice
    printf '  %b%s%b Select: ' "$TUI_ACCENT2" "$ICON_ARROW" "$TUI_RESET"
    read -r choice

    case "$choice" in
      1) menu_provisioning ;;
      2) menu_modules ;;
      3) menu_health ;;
      4) menu_quick_actions ;;
      5) menu_about ;;
      q|Q) echo; tui_notify "Goodbye!" "info"; exit 0 ;;
      *) ;;
    esac
  done
}

###############################################################################
# 1. Base provisioning menu
###############################################################################

menu_provisioning() {
  clear 2>/dev/null || true
  echo
  tui_section "Base System Provisioning" "" "$ICON_GEAR"
  echo

  echo -e "  This will run the base provisioning script which:"
  echo -e "    • Updates and upgrades all system packages"
  echo -e "    • Sets hostname to ${TUI_ACCENT2}endurance${TUI_RESET}"
  echo -e "    • Installs core tools (git, curl, wget, unzip, etc.)"
  echo -e "    • Installs Docker Engine + Compose plugin"
  echo -e "    • Installs zsh + Oh My Zsh + Powerlevel10k"
  echo -e "    • Creates Docker networks"
  echo

  if tui_confirm "Run base provisioning?" "y"; then
    echo
    if [[ -f "${PROVISION_DIR}/provision.sh" ]]; then
      if [[ $EUID -eq 0 ]]; then
        bash "${PROVISION_DIR}/provision.sh"
      else
        tui_notify "Provisioning requires root. Re-running with sudo..." "info"
        sudo bash "${PROVISION_DIR}/provision.sh"
      fi
    else
      tui_notify "Provisioning script not found at ${PROVISION_DIR}/provision.sh" "error"
    fi
  fi

  echo
  read -r -p "  Press Enter to return to main menu..."
}

###############################################################################
# 2. Module management menu
###############################################################################

menu_modules() {
  while true; do
    clear 2>/dev/null || true
    echo
    tui_section "Module Management" "" "$ICON_PACKAGE"
    echo

    local idx=1
    local -a module_names=()
    for name in portainer pihole magicmirror cicd-runner backend-template uptime-kuma watchtower nginx-proxy-manager; do
      module_names+=("$name")
      local icon
      icon="$(module_status_icon "$name")"
      printf '    %b%d%b  %b  %s — %s\n' \
        "$TUI_ACCENT2" "$idx" "$TUI_RESET" \
        "$icon" "$name" "${MODULE_DESC[$name]}"
      idx=$((idx + 1))
    done

    echo
    echo -e "    ${TUI_ACCENT2}b${TUI_RESET}  Back to main menu"
    echo

    local choice
    printf '  %b%s%b Select module: ' "$TUI_ACCENT2" "$ICON_ARROW" "$TUI_RESET"
    read -r choice

    if [[ "$choice" == "b" || "$choice" == "B" ]]; then
      return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#module_names[@]} )); then
      local selected="${module_names[$((choice - 1))]}"
      menu_module_actions "$selected"
    fi
  done
}

menu_module_actions() {
  local name="$1"

  while true; do
    clear 2>/dev/null || true
    echo
    local icon
    icon="$(module_status_icon "$name")"
    tui_section "Module: ${name}" "" "$ICON_PACKAGE"
    echo
    echo -e "  Status: ${icon}  ${name}"
    echo -e "  Path:   ${TUI_DIM}${MODULES_DIR}/${name}${TUI_RESET}"
    echo -e "  Ports:  ${MODULE_PORT[$name]}"
    echo

    echo -e "    ${TUI_ACCENT2}1${TUI_RESET}  Install (copy .env, run hooks)"
    echo -e "    ${TUI_ACCENT2}2${TUI_RESET}  Start"
    echo -e "    ${TUI_ACCENT2}3${TUI_RESET}  Stop"
    echo -e "    ${TUI_ACCENT2}4${TUI_RESET}  Restart"
    echo -e "    ${TUI_ACCENT2}5${TUI_RESET}  Update (pull + recreate)"
    echo -e "    ${TUI_ACCENT2}6${TUI_RESET}  Status"
    echo -e "    ${TUI_ACCENT2}7${TUI_RESET}  Logs (tail)"
    echo -e "    ${TUI_ACCENT2}8${TUI_RESET}  Remove (stop + delete volumes)"
    echo -e "    ${TUI_ACCENT2}9${TUI_RESET}  Edit .env"
    echo -e "    ${TUI_ACCENT2}b${TUI_RESET}  Back"
    echo

    local action
    printf '  %b%s%b Action: ' "$TUI_ACCENT2" "$ICON_ARROW" "$TUI_RESET"
    read -r action

    case "$action" in
      1) bash "${PROVISION_DIR}/module.sh" "$name" install; _pause ;;
      2) bash "${PROVISION_DIR}/module.sh" "$name" start;   _pause ;;
      3) bash "${PROVISION_DIR}/module.sh" "$name" stop;    _pause ;;
      4) bash "${PROVISION_DIR}/module.sh" "$name" restart; _pause ;;
      5) bash "${PROVISION_DIR}/module.sh" "$name" update;  _pause ;;
      6) bash "${PROVISION_DIR}/module.sh" "$name" status;  _pause ;;
      7) bash "${PROVISION_DIR}/module.sh" "$name" logs;    _pause ;;
      8)
        if tui_confirm "Remove ${name}? This will DELETE containers AND volumes." "n"; then
          bash "${PROVISION_DIR}/module.sh" "$name" remove
        fi
        _pause
        ;;
      9) _edit_env "$name"; _pause ;;
      b|B) return ;;
      *) ;;
    esac
  done
}

_edit_env() {
  local name="$1"
  local env_file="${MODULES_DIR}/${name}/.env"

  if [[ ! -f "$env_file" ]]; then
    if [[ -f "${MODULES_DIR}/${name}/.env.example" ]]; then
      cp "${MODULES_DIR}/${name}/.env.example" "$env_file"
      tui_notify "Created .env from .env.example" "info"
    else
      tui_notify "No .env or .env.example found" "warn"
      return
    fi
  fi

  local editor="${EDITOR:-nano}"
  "$editor" "$env_file"
}

_pause() {
  echo
  read -r -p "  Press Enter to continue..."
}

###############################################################################
# 3. Health dashboard
###############################################################################

menu_health() {
  clear 2>/dev/null || true
  echo
  tui_section "System Health Dashboard" "" "$ICON_CHART"
  echo

  # System info
  echo -e "  ${TUI_BOLD}System${TUI_RESET}"
  tui_divider "dots"
  printf '    %-16s  %s\n' "Hostname" "$(hostname)"
  printf '    %-16s  %s\n' "Uptime" "$(uptime -p 2>/dev/null || uptime)"
  printf '    %-16s  %s\n' "Kernel" "$(uname -r)"
  printf '    %-16s  %s\n' "Load" "$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || echo 'N/A')"
  echo

  # Memory
  if command -v free >/dev/null 2>&1; then
    local mem_info
    mem_info="$(free -h | awk '/^Mem:/ {printf "%s / %s (%.0f%%)", $3, $2, $3/$2*100}')"
    printf '    %-16s  %s\n' "Memory" "$mem_info"
  fi

  # Disk
  local disk_info
  disk_info="$(df -h / | awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}')"
  printf '    %-16s  %s\n' "Disk (/)" "$disk_info"
  echo

  # Docker
  echo -e "  ${TUI_BOLD}Docker${TUI_RESET}"
  tui_divider "dots"
  if command -v docker >/dev/null 2>&1; then
    local docker_ver
    docker_ver="$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    printf '    %-16s  %s\n' "Docker" "${docker_ver:-not running}"
    local containers_running
    containers_running="$(docker ps -q 2>/dev/null | wc -l)"
    local containers_total
    containers_total="$(docker ps -a -q 2>/dev/null | wc -l)"
    printf '    %-16s  %s running / %s total\n' "Containers" "$containers_running" "$containers_total"
  else
    printf '    %-16s  %s\n' "Docker" "not installed"
  fi
  echo

  # Module health
  echo -e "  ${TUI_BOLD}Modules${TUI_RESET}"
  tui_divider "dots"
  for name in portainer pihole magicmirror cicd-runner backend-template uptime-kuma watchtower nginx-proxy-manager; do
    local icon
    if module_is_running "$name"; then
      icon="${TUI_SUCCESS}${ICON_CHECK}${TUI_RESET}"
    else
      icon="${TUI_MUTED}${ICON_RING}${TUI_RESET}"
    fi
    printf '    %b  %-20s\n' "$icon" "$name"
  done

  echo
  read -r -p "  Press Enter to return to main menu..."
}

###############################################################################
# 4. Quick actions
###############################################################################

menu_quick_actions() {
  clear 2>/dev/null || true
  echo
  tui_section "Quick Actions" "" "$ICON_BOLT"
  echo

  echo -e "    ${TUI_ACCENT2}1${TUI_RESET}  Start ALL modules"
  echo -e "    ${TUI_ACCENT2}2${TUI_RESET}  Stop ALL modules"
  echo -e "    ${TUI_ACCENT2}3${TUI_RESET}  Update ALL modules (pull + recreate)"
  echo -e "    ${TUI_ACCENT2}4${TUI_RESET}  Docker system prune (clean up)"
  echo -e "    ${TUI_ACCENT2}5${TUI_RESET}  Show all running containers"
  echo -e "    ${TUI_ACCENT2}b${TUI_RESET}  Back"
  echo

  local choice
  printf '  %b%s%b Select: ' "$TUI_ACCENT2" "$ICON_ARROW" "$TUI_RESET"
  read -r choice

  case "$choice" in
    1)
      if tui_confirm "Start ALL modules?" "y"; then
        _all_modules "start"
      fi
      ;;
    2)
      if tui_confirm "Stop ALL modules?" "n"; then
        _all_modules "stop"
      fi
      ;;
    3)
      if tui_confirm "Update ALL modules (pull + recreate)?" "n"; then
        _all_modules "update"
      fi
      ;;
    4)
      echo
      if tui_confirm "Run docker system prune -f?" "n"; then
        docker system prune -f
        success "Docker cleanup complete."
      fi
      ;;
    5)
      echo
      docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
      ;;
    b|B) return ;;
    *) ;;
  esac

  echo
  read -r -p "  Press Enter to return to main menu..."
}

_all_modules() {
  local action="$1"
  echo
  for name in portainer pihole magicmirror cicd-runner backend-template uptime-kuma watchtower nginx-proxy-manager; do
    if [[ -f "${MODULES_DIR}/${name}/docker-compose.yml" ]]; then
      bash "${PROVISION_DIR}/module.sh" "$name" "$action" 2>/dev/null || true
    fi
  done
}

###############################################################################
# 5. About
###############################################################################

menu_about() {
  clear 2>/dev/null || true
  echo

  TUI_BOX_COLOR="$TUI_ACCENT2" tui_box_double "${ENDURANCE_NAME} v${ENDURANCE_VERSION}" \
    "" \
    "A modular, Docker-based home server platform for Debian 13." \
    "" \
    "Core modules:" \
    "  • Portainer            — Docker management UI" \
    "  • Pi-hole              — Network-wide ad blocker" \
    "  • MagicMirror²         — Smart display dashboard" \
    "  • CI/CD Runner         — GitHub Actions self-hosted runner" \
    "  • Backend Template     — Reference backend API (FastAPI)" \
    "" \
    "Infrastructure modules:" \
    "  • Uptime Kuma          — Service monitoring & Telegram alerts" \
    "  • Watchtower           — Automatic container image updater" \
    "  • Nginx Proxy Manager  — Reverse proxy + Let's Encrypt SSL" \
    "" \
    "Architecture:" \
    "  • All services run in Docker with Compose" \
    "  • Shared networks: endurance_frontend, endurance_backend" \
    "  • Modules are independent and can be toggled individually" \
    "  • NPM proxies all services behind endurance.local" \
    "" \
    "Project: https://github.com/j4ngx/homeserver"

  echo
  read -r -p "  Press Enter to return to main menu..."
}

###############################################################################
# Cleanup
###############################################################################

cleanup() {
  tput cnorm 2>/dev/null || true   # Restore cursor
}
trap cleanup EXIT

###############################################################################
# Main
###############################################################################

main() {
  # Hide cursor for cleaner TUI
  tput civis 2>/dev/null || true

  main_menu
}

main "$@"
