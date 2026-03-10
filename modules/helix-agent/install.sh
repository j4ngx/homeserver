#!/usr/bin/env bash
# =============================================================================
# Helix Agent — Module installer
# =============================================================================
# Called automatically by:  module.sh helix-agent install
#
# Steps:
#   1. Clone (or update) the axon_agent source code into ./src/
#   2. Validate the Firebase service-account.json
# =============================================================================

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${MODULE_DIR}/src"
SA_FILE="${MODULE_DIR}/service-account.json"
REPO_URL="https://github.com/j4ngx/axon_agent.git"

# Colour helpers
info()    { echo -e "\033[0;36m ℹ  $*\033[0m"; }
success() { echo -e "\033[0;32m ✔  $*\033[0m"; }
warn()    { echo -e "\033[1;33m ⚠  $*\033[0m"; }
fail()    { echo -e "\033[0;31m ✖  $*\033[0m"; exit 1; }

###############################################################################
# Step 1 — Clone or update the Helix source code
###############################################################################

echo
info "Step 1 / 2 — Source code (axon_agent)"

if [[ -d "${SRC_DIR}/.git" ]]; then
  info "Repository found at src/ — pulling latest changes..."
  git -C "$SRC_DIR" pull --ff-only
  success "Source updated to latest commit."
elif [[ -d "$SRC_DIR" ]] && [[ "$(ls -A "$SRC_DIR" 2>/dev/null)" ]]; then
  warn "src/ exists but is not a git repository — skipping clone."
  info "Make sure src/ contains a valid copy of axon_agent."
else
  info "Cloning ${REPO_URL} → src/ ..."
  git clone "$REPO_URL" "$SRC_DIR"
  success "Source cloned."
fi

###############################################################################
# Step 2 — Validate Firebase service-account.json
###############################################################################

echo
info "Step 2 / 2 — Firebase service-account.json"

if [[ ! -f "$SA_FILE" ]]; then
  echo
  warn "service-account.json not found."
  echo
  echo "  This file is required for Firebase Firestore (persistent memory)."
  echo
  echo "  How to get it:"
  echo "    1. Open https://console.firebase.google.com"
  echo "    2. Select your project  →  Settings  →  Service Accounts"
  echo "    3. Click 'Generate new private key'  →  Download the JSON"
  echo "    4. Copy the file to:"
  echo "       ${SA_FILE}"
  echo
  read -r -p "  Press Enter once the file is in place (Ctrl+C to abort)..."
  echo
fi

[[ -f "$SA_FILE" ]] || fail "service-account.json still missing. Aborting."

# Validate it is an actual service account file
if ! python3 - <<'PY' 2>/dev/null
import json, sys
d = json.load(open("${SA_FILE}".replace("\${SA_FILE}", __import__("os").environ.get("SA_FILE", ""))))
sys.exit(0 if d.get("type") == "service_account" else 1)
PY
then
  # Fallback: simpler check via grep
  if ! grep -q '"type".*"service_account"' "$SA_FILE"; then
    fail "service-account.json does not look like a valid Firebase service account file."
  fi
fi

# Secure the file — only the owner should read it
chmod 600 "$SA_FILE"
success "service-account.json validated (permissions set to 600)."

###############################################################################
# Done
###############################################################################

echo
success "Helix Agent ready."
echo
echo "  Next steps:"
echo "    Start:    ./provisioning/scripts/module.sh helix-agent start"
echo "    Logs:     ./provisioning/scripts/module.sh helix-agent logs"
echo "    Stop:     ./provisioning/scripts/module.sh helix-agent stop"
echo
echo "  Uptime Kuma monitor:"
echo "    Type: Docker Container   Name: endurance-helix-agent"
echo
