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

# ── MMM-pages ──────────────────────────────────────────────────────────────
# Note: the repo and JS file are lowercase 'pages' — must match folder name.
if [[ ! -d "${MODS_DIR}/MMM-pages" ]]; then
  echo "  → Cloning MMM-pages..."
  git clone --depth=1 https://github.com/edward-shen/MMM-pages.git "${MODS_DIR}/MMM-pages"
  echo "  ✔ MMM-pages installed."
else
  echo "  ✔ MMM-pages already present, skipping."
fi
