#!/usr/bin/env bash
# =============================================================================
# Module manager — shared helper for all endurance modules
# =============================================================================
# Provides a unified interface to install, start, stop, restart, status,
# and remove any module under modules/.
#
# Each module must have:
#   - docker-compose.yml
#   - Optionally: .env.example, install.sh, pre-start.sh
#
# Usage:
#   module.sh <module_name> <action>
#   module.sh portainer start
#   module.sh pihole stop
#   module.sh magicmirror status
# =============================================================================

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly MODULES_DIR="${PROJECT_ROOT}/modules"

###############################################################################
# Colour helpers
###############################################################################

if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' NC=''
fi

success() { echo -e "${GREEN} ✔  $*${NC}"; }
warn()    { echo -e "${YELLOW} ⚠  $*${NC}"; }
info()    { echo -e "${CYAN} ℹ  $*${NC}"; }
fail()    { echo -e "${RED} ✖  $*${NC}"; exit 1; }

###############################################################################
# Compose command detection
###############################################################################

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    fail "Neither 'docker compose' (v2) nor 'docker-compose' (v1) is available."
  fi
}

###############################################################################
# Resolve module directory
###############################################################################

resolve_module() {
  local name="$1"
  local module_dir="${MODULES_DIR}/${name}"

  if [[ ! -d "$module_dir" ]]; then
    fail "Module '${name}' not found at ${module_dir}."
  fi
  if [[ ! -f "${module_dir}/docker-compose.yml" ]]; then
    fail "Module '${name}' has no docker-compose.yml."
  fi

  echo "$module_dir"
}

###############################################################################
# Actions
###############################################################################

do_install() {
  local module_dir="$1"
  local name="$2"

  # Copy .env.example → .env if not present
  if [[ -f "${module_dir}/.env.example" ]] && [[ ! -f "${module_dir}/.env" ]]; then
    cp "${module_dir}/.env.example" "${module_dir}/.env"
    warn "Created .env from .env.example — edit ${module_dir}/.env before starting."
  fi

  # Run module-specific install script if present
  if [[ -x "${module_dir}/install.sh" ]]; then
    info "Running install.sh for ${name}..."
    bash "${module_dir}/install.sh"
  fi

  success "Module '${name}' installed."
}

do_start() {
  local module_dir="$1"
  local name="$2"
  local COMPOSE
  COMPOSE="$(compose_cmd)"

  # Run pre-start hook if present
  if [[ -x "${module_dir}/pre-start.sh" ]]; then
    bash "${module_dir}/pre-start.sh"
  fi

  info "Starting ${name}..."
  (cd "$module_dir" && $COMPOSE up -d)
  success "Module '${name}' started."
}

do_stop() {
  local module_dir="$1"
  local name="$2"
  local COMPOSE
  COMPOSE="$(compose_cmd)"

  info "Stopping ${name}..."
  (cd "$module_dir" && $COMPOSE stop)
  success "Module '${name}' stopped (containers preserved)."
}

do_restart() {
  local module_dir="$1"
  local name="$2"
  local COMPOSE
  COMPOSE="$(compose_cmd)"

  info "Restarting ${name}..."
  (cd "$module_dir" && $COMPOSE restart)
  success "Module '${name}' restarted."
}

do_update() {
  local module_dir="$1"
  local name="$2"
  local COMPOSE
  COMPOSE="$(compose_cmd)"

  info "Pulling latest images for ${name}..."
  (cd "$module_dir" && $COMPOSE pull)
  info "Recreating containers..."
  (cd "$module_dir" && $COMPOSE up -d --force-recreate)
  success "Module '${name}' updated."
}

do_status() {
  local module_dir="$1"
  local name="$2"
  local COMPOSE
  COMPOSE="$(compose_cmd)"

  echo
  echo -e "${BOLD}  Module: ${CYAN}${name}${NC}"
  echo -e "${DIM}  Path: ${module_dir}${NC}"
  echo

  (cd "$module_dir" && $COMPOSE ps)
}

do_logs() {
  local module_dir="$1"
  local name="$2"
  local COMPOSE
  COMPOSE="$(compose_cmd)"

  (cd "$module_dir" && $COMPOSE logs --tail=50 -f)
}

do_remove() {
  local module_dir="$1"
  local name="$2"
  local COMPOSE
  COMPOSE="$(compose_cmd)"

  warn "This will stop containers AND remove volumes for '${name}'."
  read -r -p "  Are you sure? [y/N]: " yn
  case "${yn,,}" in
    y|yes)
      (cd "$module_dir" && $COMPOSE down -v)
      success "Module '${name}' removed (containers + volumes)."
      ;;
    *)
      info "Aborted."
      ;;
  esac
}

###############################################################################
# List all modules
###############################################################################

do_list() {
  echo
  echo -e "${BOLD}  Available modules:${NC}"
  echo

  for d in "${MODULES_DIR}"/*/; do
    [[ -d "$d" ]] || continue
    local name
    name="$(basename "$d")"
    local status_icon="${DIM}○${NC}"

    if [[ -f "${d}/docker-compose.yml" ]]; then
      local COMPOSE
      COMPOSE="$(compose_cmd)"
      local running
      running="$(cd "$d" && $COMPOSE ps --status running -q 2>/dev/null | wc -l)"
      if (( running > 0 )); then
        status_icon="${GREEN}●${NC}"
      fi
    fi

    printf '    %b  %s\n' "$status_icon" "$name"
  done
  echo
}

###############################################################################
# Usage
###############################################################################

usage() {
  cat <<EOF
${BOLD}Endurance Module Manager${NC}

${BOLD}USAGE${NC}
  $(basename "$0") <module> <action>
  $(basename "$0") list

${BOLD}ACTIONS${NC}
  install    Copy .env.example, run install.sh if present
  start      Start the Docker Compose stack
  stop       Stop the Docker Compose stack
  restart    Stop and start the stack
  update     Pull latest images and recreate containers
  status     Show running containers
  logs       Tail container logs
  remove     Stop containers and remove volumes

${BOLD}EXAMPLES${NC}
  $(basename "$0") list
  $(basename "$0") portainer start
  $(basename "$0") pihole status
  $(basename "$0") magicmirror logs
  $(basename "$0") backend-template update
EOF
}

###############################################################################
# Main
###############################################################################

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local command="$1"

  if [[ "$command" == "list" ]]; then
    do_list
    exit 0
  fi

  if [[ $# -lt 2 ]]; then
    usage
    exit 1
  fi

  local module_name="$1"
  local action="$2"
  local module_dir
  module_dir="$(resolve_module "$module_name")"

  case "$action" in
    install) do_install "$module_dir" "$module_name" ;;
    start)   do_start   "$module_dir" "$module_name" ;;
    stop)    do_stop    "$module_dir" "$module_name" ;;
    restart) do_restart "$module_dir" "$module_name" ;;
    update)  do_update  "$module_dir" "$module_name" ;;
    status)  do_status  "$module_dir" "$module_name" ;;
    logs)    do_logs    "$module_dir" "$module_name" ;;
    remove)  do_remove  "$module_dir" "$module_name" ;;
    *)       fail "Unknown action '${action}'. Use: install|start|stop|restart|update|status|logs|remove" ;;
  esac
}

main "$@"
