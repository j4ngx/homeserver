#!/usr/bin/env bash
# =============================================================================
# CI/CD Runner — Native installation (systemd) alternative
# =============================================================================
# Use this script if you prefer running the GitHub Actions runner as a
# native systemd service instead of Docker.
#
# Usage:
#   sudo ./install-native.sh --owner <github_owner> --repo <repo> --token <token>
# =============================================================================

set -Eeuo pipefail

RUNNER_VERSION="2.321.0"
RUNNER_ARCH="x64"
RUNNER_DIR="/opt/actions-runner"
RUNNER_USER="${SUDO_USER:-$(whoami)}"
RUNNER_LABELS="self-hosted,linux,endurance"

GITHUB_OWNER=""
GITHUB_REPO=""
RUNNER_TOKEN=""

###############################################################################
# Colour helpers
###############################################################################

if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

success() { echo -e "${GREEN} ✔  $*${NC}"; }
warn()    { echo -e "${YELLOW} ⚠  $*${NC}"; }
info()    { echo -e "${CYAN} ℹ  $*${NC}"; }
fail()    { echo -e "${RED} ✖  $*${NC}"; exit 1; }

###############################################################################
# Parse arguments
###############################################################################

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)  shift; GITHUB_OWNER="$1" ;;
    --repo)   shift; GITHUB_REPO="$1" ;;
    --token)  shift; RUNNER_TOKEN="$1" ;;
    --labels) shift; RUNNER_LABELS="$1" ;;
    --help|-h)
      echo "Usage: $(basename "$0") --owner <owner> --repo <repo> --token <token> [--labels <labels>]"
      exit 0
      ;;
    *) fail "Unknown argument: $1" ;;
  esac
  shift
done

[[ -z "$GITHUB_OWNER" ]] && fail "Missing --owner."
[[ -z "$GITHUB_REPO" ]]  && fail "Missing --repo."
[[ -z "$RUNNER_TOKEN" ]] && fail "Missing --token."

###############################################################################
# Install runner
###############################################################################

[[ $EUID -ne 0 ]] && fail "Run with sudo."

info "Installing GitHub Actions runner v${RUNNER_VERSION}..."

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [[ ! -f "${RUNNER_DIR}/run.sh" ]]; then
  tarball="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
  curl -fsSL -o "$tarball" \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}"
  tar xzf "$tarball"
  rm -f "$tarball"
  chown -R "${RUNNER_USER}:${RUNNER_USER}" "$RUNNER_DIR"
  success "Runner binaries extracted."
else
  success "Runner binaries already present."
fi

###############################################################################
# Configure runner
###############################################################################

if [[ ! -f "${RUNNER_DIR}/.runner" ]]; then
  info "Configuring runner..."
  sudo -u "$RUNNER_USER" "${RUNNER_DIR}/config.sh" \
    --url "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}" \
    --token "$RUNNER_TOKEN" \
    --name "endurance-runner" \
    --labels "$RUNNER_LABELS" \
    --work "_work" \
    --unattended \
    --replace
  success "Runner configured."
else
  success "Runner already configured."
fi

###############################################################################
# Install as systemd service
###############################################################################

info "Installing systemd service..."
cd "$RUNNER_DIR"
sudo ./svc.sh install "$RUNNER_USER"
sudo ./svc.sh start
sudo systemctl enable "actions.runner.${GITHUB_OWNER}-${GITHUB_REPO}.endurance-runner.service" 2>/dev/null || true

success "Runner installed and running as systemd service."
echo
info "Check status:  sudo ./svc.sh status"
info "View logs:     journalctl -u actions.runner.*.service -f"
