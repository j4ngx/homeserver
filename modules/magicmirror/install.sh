#!/usr/bin/env bash
# =============================================================================
# MagicMirror² — install hook
# =============================================================================
# Called automatically by: module.sh magicmirror install
#
# Clones third-party modules required by config.js:
#   - MMM-Pages  (edward-shen/MMM-pages)  — multi-page layout controller
# =============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODS_DIR="${SCRIPT_DIR}/modules"

mkdir -p "${MODS_DIR}"

# ── MMM-Pages ──────────────────────────────────────────────────────────────
if [[ ! -d "${MODS_DIR}/MMM-Pages" ]]; then
  echo "  → Cloning MMM-Pages..."
  git clone --depth=1 https://github.com/edward-shen/MMM-pages.git "${MODS_DIR}/MMM-Pages"
  echo "  ✔ MMM-Pages installed."
else
  echo "  ✔ MMM-Pages already present, skipping."
fi
