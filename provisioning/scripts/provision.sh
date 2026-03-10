#!/usr/bin/env bash
# =============================================================================
# Endurance — Base system provisioning script
# =============================================================================
# Idempotent provisioning for a fresh Debian 13 host:
#   • Full apt update + upgrade
#   • Set hostname to "endurance" with consistent /etc/hostname & /etc/hosts
#   • Install core packages (git, curl, wget, unzip, ca-certificates)
#   • Install Docker Engine + Docker Compose plugin (official repo)
#   • Install zsh + oh-my-zsh + powerlevel10k (non-interactive)
#   • Add main user to docker group, set zsh as default shell
#
# Safe to re-run.  Requires sudo.
#
# Usage:
#   sudo ./provision.sh [--user <username>] [--hostname <name>] [--skip-zsh]
# =============================================================================

set -Eeuo pipefail

###############################################################################
# Defaults
###############################################################################

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENDURANCE_USER="${SUDO_USER:-$(whoami)}"
ENDURANCE_HOSTNAME="endurance"
SKIP_ZSH=false
VERBOSE=false

###############################################################################
# Colour helpers
###############################################################################

if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' NC=''
fi

log()     { echo -e "    $*"; }
success() { echo -e "${GREEN} ✔  $*${NC}"; }
warn()    { echo -e "${YELLOW} ⚠  $*${NC}"; }
info()    { echo -e "${CYAN} ℹ  $*${NC}"; }
fail()    { echo -e "${RED} ✖  $*${NC}"; exit 1; }

section() {
  echo
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  ${BOLD}$*${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

###############################################################################
# CLI argument parsing
###############################################################################

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)      shift; ENDURANCE_USER="$1" ;;
      --hostname)  shift; ENDURANCE_HOSTNAME="$1" ;;
      --skip-zsh)  SKIP_ZSH=true ;;
      --verbose)   VERBOSE=true ;;
      --help|-h)
        echo "Usage: $(basename "$0") [--user <username>] [--hostname <name>] [--skip-zsh] [--verbose]"
        exit 0
        ;;
      *) fail "Unknown argument: $1" ;;
    esac
    shift
  done
}

###############################################################################
# Root check
###############################################################################

require_root() {
  if [[ $EUID -ne 0 ]]; then
    fail "This script must be run as root (use sudo)."
  fi
}

###############################################################################
# 1. System update & upgrade
###############################################################################

system_update() {
  section "System update & upgrade"

  apt-get update -qq
  success "Package index updated."

  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
  success "System packages upgraded."

  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -qq
  success "Distribution upgrade complete."

  apt-get autoremove -y -qq
  apt-get autoclean -qq
}

###############################################################################
# 2. Hostname configuration
###############################################################################

configure_hostname() {
  section "Hostname configuration"

  local current_hostname
  current_hostname="$(hostname)"

  if [[ "$current_hostname" == "$ENDURANCE_HOSTNAME" ]]; then
    success "Hostname already set to '${ENDURANCE_HOSTNAME}'."
  else
    # Validate hostname (RFC 1123)
    if ! [[ "$ENDURANCE_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
      fail "Invalid hostname '${ENDURANCE_HOSTNAME}'."
    fi

    hostnamectl set-hostname "$ENDURANCE_HOSTNAME"
    success "Hostname set to '${ENDURANCE_HOSTNAME}'."
  fi

  # /etc/hostname
  echo "$ENDURANCE_HOSTNAME" > /etc/hostname
  success "/etc/hostname updated."

  # /etc/hosts — ensure 127.0.1.1 maps to the hostname
  if grep -q "^127\.0\.1\.1" /etc/hosts 2>/dev/null; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${ENDURANCE_HOSTNAME}/" /etc/hosts
  else
    echo -e "127.0.1.1\t${ENDURANCE_HOSTNAME}" >> /etc/hosts
  fi

  # Ensure 127.0.0.1 has localhost
  if ! grep -q "^127\.0\.0\.1.*localhost" /etc/hosts 2>/dev/null; then
    sed -i '1i 127.0.0.1\tlocalhost' /etc/hosts
  fi

  success "/etc/hosts consistent (127.0.1.1 → ${ENDURANCE_HOSTNAME})."
}

###############################################################################
# 3. Core system packages
###############################################################################

install_core_packages() {
  section "Core system packages"

  local pkgs=(
    git curl wget unzip ca-certificates
    gnupg lsb-release apt-transport-https
    software-properties-common
    jq htop tree ncdu tmux
    ufw fail2ban
  )

  local missing=()
  for pkg in "${pkgs[@]}"; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
      missing+=("$pkg")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    success "All ${#pkgs[@]} core packages already installed."
    return
  fi

  info "Installing ${#missing[@]} missing packages..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
  success "Core packages installed."
}

###############################################################################
# 4. Docker Engine + Compose plugin
###############################################################################

install_docker() {
  section "Docker Engine + Compose plugin"

  if command -v docker >/dev/null 2>&1; then
    local docker_ver
    docker_ver="$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    success "Docker already installed (${docker_ver})."
  else
    info "Installing Docker from official repository..."

    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    local arch
    arch="$(dpkg --print-architecture)"
    local codename
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian ${codename} stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin

    success "Docker Engine installed."
  fi

  # Ensure Docker is running
  systemctl enable --now docker
  success "Docker daemon enabled and running."

  # Add user to docker group
  if ! groups "$ENDURANCE_USER" 2>/dev/null | grep -qw docker; then
    usermod -aG docker "$ENDURANCE_USER"
    success "User '${ENDURANCE_USER}' added to docker group."
    warn "Log out and back in for group changes to take effect."
  else
    success "User '${ENDURANCE_USER}' already in docker group."
  fi

  # Verify compose plugin
  if docker compose version >/dev/null 2>&1; then
    local compose_ver
    compose_ver="$(docker compose version --short 2>/dev/null)"
    success "Docker Compose plugin available (${compose_ver})."
  else
    warn "Docker Compose plugin not detected — install manually."
  fi
}

###############################################################################
# 5. Zsh + Oh My Zsh + Powerlevel10k
###############################################################################

install_zsh_stack() {
  section "Zsh + Oh My Zsh + Powerlevel10k"

  if [[ "$SKIP_ZSH" == true ]]; then
    info "Zsh installation skipped (--skip-zsh)."
    return
  fi

  # Install zsh
  if ! command -v zsh >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zsh
    success "Zsh installed."
  else
    success "Zsh already installed."
  fi

  local user_home
  user_home="$(eval echo "~${ENDURANCE_USER}")"

  # Oh My Zsh (non-interactive, idempotent)
  if [[ -d "${user_home}/.oh-my-zsh" ]]; then
    success "Oh My Zsh already installed."
  else
    info "Installing Oh My Zsh for ${ENDURANCE_USER}..."
    sudo -u "$ENDURANCE_USER" sh -c \
      'RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    success "Oh My Zsh installed."
  fi

  # Powerlevel10k theme
  local p10k_dir="${user_home}/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ -d "$p10k_dir" ]]; then
    success "Powerlevel10k already installed."
  else
    info "Cloning Powerlevel10k..."
    sudo -u "$ENDURANCE_USER" git clone --depth=1 \
      https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    success "Powerlevel10k installed."
  fi

  # Set theme in .zshrc
  local zshrc="${user_home}/.zshrc"
  if [[ -f "$zshrc" ]]; then
    if grep -q 'ZSH_THEME=' "$zshrc"; then
      sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc"
    else
      echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$zshrc"
    fi
    success "Powerlevel10k set as default theme in .zshrc."
  fi

  # zsh-autosuggestions
  local autosug_dir="${user_home}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  if [[ ! -d "$autosug_dir" ]]; then
    sudo -u "$ENDURANCE_USER" git clone --depth=1 \
      https://github.com/zsh-users/zsh-autosuggestions "$autosug_dir"
    success "zsh-autosuggestions plugin installed."
  fi

  # zsh-syntax-highlighting
  local synhi_dir="${user_home}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  if [[ ! -d "$synhi_dir" ]]; then
    sudo -u "$ENDURANCE_USER" git clone --depth=1 \
      https://github.com/zsh-users/zsh-syntax-highlighting "$synhi_dir"
    success "zsh-syntax-highlighting plugin installed."
  fi

  # Enable useful plugins
  if [[ -f "$zshrc" ]] && grep -q '^plugins=' "$zshrc"; then
    sed -i 's/^plugins=.*/plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting)/' "$zshrc"
    success "Zsh plugins configured."
  fi

  # Set zsh as default shell
  local current_shell
  current_shell="$(getent passwd "$ENDURANCE_USER" | cut -d: -f7)"
  if [[ "$current_shell" != *"zsh"* ]]; then
    chsh -s "$(which zsh)" "$ENDURANCE_USER"
    success "Default shell changed to zsh for ${ENDURANCE_USER}."
  else
    success "Zsh is already the default shell for ${ENDURANCE_USER}."
  fi
}

###############################################################################
# 6. Docker networks (shared across modules)
###############################################################################

create_docker_networks() {
  section "Docker networks"

  local networks=("endurance_frontend" "endurance_backend")

  for net in "${networks[@]}"; do
    if docker network ls --format '{{.Name}}' | grep -qx "$net"; then
      success "Docker network '${net}' already exists."
    else
      docker network create "$net"
      success "Docker network '${net}' created."
    fi
  done
}

###############################################################################
# 7. Create module directories
###############################################################################

create_module_dirs() {
  section "Module directory structure"

  local modules_dir="${PROJECT_ROOT}/modules"
  local dirs=(
    "${modules_dir}/cicd-runner"
    "${modules_dir}/magicmirror"
    "${modules_dir}/pihole"
    "${modules_dir}/portainer"
    "${modules_dir}/backend-template"
    "${modules_dir}/uptime-kuma"
    "${modules_dir}/watchtower"
    "${modules_dir}/nginx-proxy-manager"
  )

  for d in "${dirs[@]}"; do
    mkdir -p "$d"
  done

  success "Module directories created under ${modules_dir}."
}

###############################################################################
# 8. Basic firewall (UFW)
###############################################################################

configure_ufw() {
  section "Firewall (UFW)"

  if ! command -v ufw >/dev/null 2>&1; then
    warn "UFW not found — skipping firewall setup."
    return
  fi

  # Default policies
  ufw default deny incoming  >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1

  # SSH (always allow)
  ufw allow 22/tcp comment "SSH" >/dev/null 2>&1

  # Module ports — allow from LAN only
  ufw allow 53/tcp   comment "Pi-hole DNS"          >/dev/null 2>&1
  ufw allow 53/udp   comment "Pi-hole DNS"          >/dev/null 2>&1
  ufw allow 80/tcp   comment "NPM HTTP"             >/dev/null 2>&1
  ufw allow 81/tcp   comment "NPM Admin UI"         >/dev/null 2>&1
  ufw allow 443/tcp  comment "NPM HTTPS"            >/dev/null 2>&1
  ufw allow 3001/tcp comment "Uptime Kuma"          >/dev/null 2>&1
  ufw allow 8080/tcp comment "Pi-hole Web UI"       >/dev/null 2>&1
  ufw allow 8181/tcp comment "MagicMirror"          >/dev/null 2>&1
  ufw allow 9443/tcp comment "Portainer HTTPS"      >/dev/null 2>&1
  ufw allow 8000/tcp comment "Backend API"          >/dev/null 2>&1

  # Enable if not already active
  if ufw status | grep -q "Status: inactive"; then
    echo "y" | ufw enable >/dev/null 2>&1
    success "UFW enabled with default deny incoming."
  else
    ufw reload >/dev/null 2>&1
    success "UFW already active — rules reloaded."
  fi

  info "Review rules with: sudo ufw status numbered"
}

###############################################################################
# Main
###############################################################################

main() {
  parse_args "$@"
  require_root

  echo
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║          Endurance — Base System Provisioning               ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo
  echo -e "  ${DIM}User    :${NC} ${ENDURANCE_USER}"
  echo -e "  ${DIM}Hostname:${NC} ${ENDURANCE_HOSTNAME}"
  echo -e "  ${DIM}Date    :${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo

  system_update
  configure_hostname
  install_core_packages
  install_docker
  install_zsh_stack
  create_docker_networks
  create_module_dirs
  configure_ufw

  echo
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  ✔  Base provisioning complete!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo
  echo -e "  Next steps:"
  echo -e "    1. Log out and back in (docker group + zsh shell)"
  echo -e "    2. Run the TUI installer: ${CYAN}./tui/endurance_tui.sh${NC}"
  echo -e "    3. Or deploy modules individually from ${CYAN}modules/${NC}"
  echo
}

main "$@"
