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
    warn "Created .env from .env.example."
  fi

  # Prompt for any required variables that still have placeholder values
  prompt_required_vars "$module_dir"

  # Run module-specific install script if present
  if [[ -x "${module_dir}/install.sh" ]]; then
    info "Running install.sh for ${name}..."
    bash "${module_dir}/install.sh"
  fi

  success "Module '${name}' installed."
}

###############################################################################
# Required variable prompting
###############################################################################
#
# Reads .env.example looking for annotation comments placed on the line(s)
# immediately before a variable assignment.  Supported annotations:
#
#   # @required        — variable must be set (prompt if placeholder)
#   # @secret          — use hidden input (passwords, tokens)
#   # @desc <text>     — shown in the prompt as context
#
# Placeholder detection: a value is considered unfilled when it is empty or
# matches common placeholder patterns (changeme, your_*, REPLACE_WITH_*, etc.)
#
# Called automatically by do_install and (interactively) by do_start.
###############################################################################

_is_placeholder() {
  local val="$1"
  [[ -z "$val" ]] && return 0
  local lower="${val,,}"
  local patterns=(
    "changeme" "your_" "your-" "replace_with_" "_here"
    "example.com" "placeholder" "<" ">"
  )
  for p in "${patterns[@]}"; do
    [[ "$lower" == *"${p,,}"* ]] && return 0
  done
  return 1
}

prompt_required_vars() {
  local module_dir="$1"
  local env_file="${module_dir}/.env"
  local example_file="${module_dir}/.env.example"

  [[ -f "$example_file" ]] || return 0
  [[ -f "$env_file" ]]     || return 0

  # ── Pass 1: collect annotated variables from .env.example ────────────
  local -a annotated_vars=()
  declare -A _var_secret=()
  declare -A _var_desc=()

  local pending_required=false
  local pending_secret=false
  local pending_desc=""

  while IFS= read -r line; do
    # Blank line — reset pending annotation state
    if [[ -z "${line// }" ]]; then
      pending_required=false
      pending_secret=false
      pending_desc=""
      continue
    fi

    if [[ "$line" =~ ^#.*@required ]]; then pending_required=true; fi
    if [[ "$line" =~ ^#.*@secret   ]]; then pending_secret=true;   fi
    if [[ "$line" =~ ^#[[:space:]]*@desc[[:space:]]+(.*) ]]; then
      pending_desc="${BASH_REMATCH[1]}"
    fi

    # Variable assignment — consume pending annotations
    if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)= ]]; then
      local varname="${BASH_REMATCH[1]}"
      if [[ "$pending_required" == true ]]; then
        annotated_vars+=("$varname")
        _var_secret["$varname"]="$pending_secret"
        _var_desc["$varname"]="$pending_desc"
      fi
      pending_required=false
      pending_secret=false
      pending_desc=""
    fi
  done < "$example_file"

  [[ ${#annotated_vars[@]} -eq 0 ]] && return 0

  # ── Pass 2: find which ones still hold placeholder values ─────────────
  local -a needs_prompt=()
  for var in "${annotated_vars[@]}"; do
    local current_val
    # grep exits 1 when no match; || true prevents set -e from killing the script
    current_val="$(grep -E "^${var}=" "$env_file" 2>/dev/null | head -1 \
                   | sed 's/^[^=]*=//' | sed 's/[[:space:]]*#.*//' | xargs || true)"
    _is_placeholder "$current_val" && needs_prompt+=("$var")
  done

  [[ ${#needs_prompt[@]} -eq 0 ]] && return 0

  # ── Pass 3: prompt the user ───────────────────────────────────────────
  echo
  echo -e "  ${YELLOW}⚠  Required configuration — please fill in the following values:${NC}"
  echo

  local changed=false
  for var in "${needs_prompt[@]}"; do
    local desc="${_var_desc[$var]:-}"
    local is_sec="${_var_secret[$var]:-false}"

    local label
    if [[ -n "$desc" ]]; then
      label="  ${CYAN}${BOLD}${var}${NC} ${DIM}(${desc})${NC}: "
    else
      label="  ${CYAN}${BOLD}${var}${NC}: "
    fi

    local new_val=""
    if [[ "$is_sec" == true ]]; then
      # shellcheck disable=SC2162
      read -s -p "$(echo -e "${label}")" new_val
      echo   # newline after hidden input
    else
      # shellcheck disable=SC2162
      read -r -p "$(echo -e "${label}")" new_val
    fi

    if [[ -n "$new_val" ]]; then
      # Escape delimiters for sed
      local esc_val
      esc_val="$(printf '%s' "$new_val" | sed 's|[/\\&]|\\&|g')"
      if grep -qE "^${var}=" "$env_file" 2>/dev/null; then
        # Variable exists in .env — update in place
        sed -i "s|^${var}=.*|${var}=${esc_val}|" "$env_file"
      else
        # Variable missing from .env (e.g. .env created before it was added
        # to .env.example) — append it
        printf '\n%s=%s\n' "$var" "$new_val" >> "$env_file"
      fi
      changed=true
    else
      warn "  ${var} left unchanged — edit ${env_file} before starting."
    fi
  done

  echo
  [[ "$changed" == true ]] && success "Configuration saved to .env."
}

do_start() {
  local module_dir="$1"
  local name="$2"
  local COMPOSE
  COMPOSE="$(compose_cmd)"

  # Auto-install if .env was never created, then prompt for required vars.
  # When running non-interactively (CI) skip prompts entirely.
  if [[ -f "${module_dir}/.env.example" ]] && [[ ! -f "${module_dir}/.env" ]]; then
    cp "${module_dir}/.env.example" "${module_dir}/.env"
    warn "Created .env from .env.example."
  fi
  [[ -t 0 ]] && prompt_required_vars "$module_dir"

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

  # Prompt for any still-unset required vars before recreating
  [[ -t 0 ]] && prompt_required_vars "$module_dir"

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
