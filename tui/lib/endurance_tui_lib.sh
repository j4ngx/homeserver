#!/usr/bin/env bash
# shellcheck disable=SC2034   # colour/icon vars used externally by sourcing scripts
# =============================================================================
# tui/lib/endurance_tui_lib.sh — Professional Terminal UI library for Endurance
# =============================================================================
# Derived from the GLaDOS installer TUI library with full parity.
# Provides polished, animated UI primitives:
#   • Box drawing with Unicode borders (single, double, rounded, heavy)
#   • Dynamic progress bars with sub-block precision
#   • Step-tracker (pipeline visualisation)
#   • Animated spinners (multiple styles)
#   • Styled prompts, menus, and interactive selection
#   • Terminal capability detection
#   • Notification bars and section headers
# =============================================================================

[[ -n "${_ENDURANCE_TUI_LIB_LOADED:-}" ]] && return 0
readonly _ENDURANCE_TUI_LIB_LOADED=1

###############################################################################
# Global defaults
###############################################################################

NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

###############################################################################
# Extended colour palette (256-colour)
###############################################################################

TUI_ACCENT='\033[38;5;141m'        # Soft purple
TUI_ACCENT2='\033[38;5;39m'        # Electric blue
TUI_ACCENT3='\033[38;5;214m'       # Amber/orange
TUI_SUCCESS='\033[38;5;78m'        # Soft green
TUI_WARNING='\033[38;5;220m'       # Gold
TUI_ERROR='\033[38;5;196m'         # Bright red
TUI_MUTED='\033[38;5;243m'         # Grey
TUI_WHITE='\033[38;5;255m'         # Bright white
TUI_HEADER_BG='\033[48;5;236m'     # Dark grey background
TUI_HIGHLIGHT='\033[38;5;117m'     # Light cyan
TUI_ORANGE='\033[38;5;208m'        # Orange

TUI_BOLD='\033[1m'
TUI_DIM='\033[2m'
TUI_ITALIC='\033[3m'
TUI_UNDERLINE='\033[4m'
TUI_BLINK='\033[5m'
TUI_REVERSE='\033[7m'
TUI_RESET='\033[0m'

# Disable colours when output is not a terminal
if [[ ! -t 1 ]]; then
  TUI_ACCENT='' TUI_ACCENT2='' TUI_ACCENT3='' TUI_SUCCESS='' TUI_WARNING=''
  TUI_ERROR='' TUI_MUTED='' TUI_WHITE='' TUI_HEADER_BG='' TUI_HIGHLIGHT=''
  TUI_ORANGE='' TUI_BOLD='' TUI_DIM='' TUI_ITALIC='' TUI_UNDERLINE=''
  TUI_BLINK='' TUI_REVERSE='' TUI_RESET=''
fi

###############################################################################
# Terminal geometry helpers
###############################################################################

tui_term_width() {
  local w
  w="$(tput cols 2>/dev/null || echo 80)"
  (( w < 40 )) && w=40
  (( w > 120 )) && w=120
  echo "$w"
}

tui_term_height() {
  tput lines 2>/dev/null || echo 24
}

###############################################################################
# Unicode box-drawing characters
###############################################################################

readonly BOX_TL='╭' BOX_TR='╮' BOX_BL='╰' BOX_BR='╯'
readonly BOX_H='─' BOX_V='│'
readonly BOX_LT='├' BOX_RT='┤' BOX_TT='┬' BOX_BT='┴' BOX_CROSS='┼'

readonly BOX2_TL='╔' BOX2_TR='╗' BOX2_BL='╚' BOX2_BR='╝'
readonly BOX2_H='═' BOX2_V='║'

readonly BOXH_H='━' BOXH_V='┃'

# Block elements for progress bars
readonly BLOCK_FULL='█' BLOCK_7='▉' BLOCK_6='▊' BLOCK_5='▋'
readonly BLOCK_4='▌' BLOCK_3='▍' BLOCK_2='▎' BLOCK_1='▏' BLOCK_EMPTY='░'

# Status icons
readonly ICON_CHECK='✔' ICON_CROSS='✖' ICON_WARN='⚠' ICON_INFO='ℹ'
readonly ICON_ARROW='▸' ICON_DOT='●' ICON_RING='○' ICON_STAR='★'
readonly ICON_ROCKET='🚀' ICON_GEAR='⚙' ICON_SHIELD='🛡' ICON_BOLT='⚡'
readonly ICON_PACKAGE='📦' ICON_GLOBE='🌐' ICON_MIC='🎙' ICON_LOCK='🔒'
readonly ICON_CLOCK='🕐' ICON_CHART='📊' ICON_SPARKLE='✨'

###############################################################################
# Internal helpers
###############################################################################

_tui_repeat() {
  local char="$1"
  local count="$2"
  (( count <= 0 )) && return
  local _buf
  printf -v _buf '%*s' "$count" ''
  printf '%s' "${_buf// /$char}"
}

_tui_strip_ansi() {
  printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

_tui_center() {
  local text="$1"
  local w
  w="$(tui_term_width)"
  local stripped
  stripped="$(_tui_strip_ansi "$text")"
  local pad=$(( (w - ${#stripped}) / 2 ))
  (( pad < 0 )) && pad=0
  _tui_repeat ' ' "$pad"
  printf '%b\n' "$text"
}

###############################################################################
# Box drawing — rounded corners
###############################################################################

tui_box() {
  local title="${1:-}"; shift
  local w
  w="$(tui_term_width)"
  local inner=$((w - 4))
  local color="${TUI_BOX_COLOR:-$TUI_ACCENT}"

  printf '%b' "$color"
  printf '  %s' "$BOX_TL"
  _tui_repeat "$BOX_H" "$inner"
  printf '%s' "$BOX_TR"
  printf '%b\n' "$TUI_RESET"

  if [[ -n "$title" ]]; then
    local stripped
    stripped="$(_tui_strip_ansi "$title")"
    local pad=$((inner - ${#stripped} - 2))
    (( pad < 0 )) && pad=0
    printf '%b' "$color"
    printf '  %s ' "$BOX_V"
    printf '%b%b%s%b' "$TUI_BOLD" "$TUI_WHITE" "$title" "$TUI_RESET"
    printf '%b' "$color"
    _tui_repeat ' ' "$pad"
    printf ' %s' "$BOX_V"
    printf '%b\n' "$TUI_RESET"

    printf '%b' "$color"
    printf '  %s' "$BOX_LT"
    _tui_repeat "$BOX_H" "$inner"
    printf '%s' "$BOX_RT"
    printf '%b\n' "$TUI_RESET"
  fi

  local line
  for line in "$@"; do
    local stripped
    stripped="$(_tui_strip_ansi "$line")"
    local pad=$((inner - ${#stripped} - 2))
    (( pad < 0 )) && pad=0
    printf '%b' "$color"
    printf '  %s ' "$BOX_V"
    printf '%b' "$TUI_RESET"
    printf '%b' "$line"
    _tui_repeat ' ' "$pad"
    printf '%b %s' "$color" "$BOX_V"
    printf '%b\n' "$TUI_RESET"
  done

  printf '%b' "$color"
  printf '  %s' "$BOX_BL"
  _tui_repeat "$BOX_H" "$inner"
  printf '%s' "$BOX_BR"
  printf '%b\n' "$TUI_RESET"
}

###############################################################################
# Box drawing — double-line (emphasis)
###############################################################################

tui_box_double() {
  local title="${1:-}"; shift
  local w
  w="$(tui_term_width)"
  local inner=$((w - 4))
  local color="${TUI_BOX_COLOR:-$TUI_ACCENT}"

  printf '%b' "$color"
  printf '  %s' "$BOX2_TL"
  _tui_repeat "$BOX2_H" "$inner"
  printf '%s' "$BOX2_TR"
  printf '%b\n' "$TUI_RESET"

  if [[ -n "$title" ]]; then
    local stripped
    stripped="$(_tui_strip_ansi "$title")"
    local pad=$((inner - ${#stripped} - 2))
    (( pad < 0 )) && pad=0
    printf '%b' "$color"
    printf '  %s ' "$BOX2_V"
    printf '%b%b%s%b' "$TUI_BOLD" "$TUI_WHITE" "$title" "$TUI_RESET"
    printf '%b' "$color"
    _tui_repeat ' ' "$pad"
    printf ' %s' "$BOX2_V"
    printf '%b\n' "$TUI_RESET"

    printf '%b' "$color"
    printf '  %s' "$BOX2_V"
    _tui_repeat "$BOX2_H" "$inner"
    printf '%s' "$BOX2_V"
    printf '%b\n' "$TUI_RESET"
  fi

  local line
  for line in "$@"; do
    local stripped
    stripped="$(_tui_strip_ansi "$line")"
    local pad=$((inner - ${#stripped} - 2))
    (( pad < 0 )) && pad=0
    printf '%b' "$color"
    printf '  %s ' "$BOX2_V"
    printf '%b' "$TUI_RESET"
    printf '%b' "$line"
    _tui_repeat ' ' "$pad"
    printf '%b %s' "$color" "$BOX2_V"
    printf '%b\n' "$TUI_RESET"
  done

  printf '%b' "$color"
  printf '  %s' "$BOX2_BL"
  _tui_repeat "$BOX2_H" "$inner"
  printf '%s' "$BOX2_BR"
  printf '%b\n' "$TUI_RESET"
}

###############################################################################
# Horizontal rule / divider
###############################################################################

tui_divider() {
  local style="${1:-single}"
  local color="${2:-$TUI_MUTED}"
  local w
  w="$(tui_term_width)"
  local inner=$((w - 4))

  printf '%b  ' "$color"
  case "$style" in
    double) _tui_repeat "$BOX2_H" "$inner" ;;
    heavy)  _tui_repeat "$BOXH_H" "$inner" ;;
    dots)   _tui_repeat "·" "$inner" ;;
    *)      _tui_repeat "$BOX_H" "$inner" ;;
  esac
  printf '%b\n' "$TUI_RESET"
}

###############################################################################
# Progress bar
###############################################################################

tui_progress() {
  local current="$1"
  local total="$2"
  local label="${3:-}"
  local bar_width=30
  local pct=$((current * 100 / total))
  local filled=$((current * bar_width / total))
  local empty=$((bar_width - filled))

  local remain=$(( (current * bar_width * 8 / total) % 8 ))
  local sub_blocks=("" "$BLOCK_1" "$BLOCK_2" "$BLOCK_3" "$BLOCK_4" "$BLOCK_5" "$BLOCK_6" "$BLOCK_7")

  local bar_color="$TUI_ACCENT2"
  (( pct >= 50 )) && bar_color="$TUI_ACCENT"
  (( pct >= 80 )) && bar_color="$TUI_SUCCESS"

  printf '\r  '
  printf '%b' "$bar_color"
  _tui_repeat "$BLOCK_FULL" "$filled"
  if (( empty > 0 && remain > 0 )); then
    printf '%s' "${sub_blocks[$remain]}"
    printf '%b' "$TUI_MUTED"
    _tui_repeat "$BLOCK_EMPTY" $((empty - 1))
  else
    printf '%b' "$TUI_MUTED"
    _tui_repeat "$BLOCK_EMPTY" "$empty"
  fi
  printf '%b' "$TUI_RESET"
  printf ' %b%3d%%%b' "$TUI_BOLD" "$pct" "$TUI_RESET"

  if [[ -n "$label" ]]; then
    printf '  %b%s%b' "$TUI_MUTED" "$label" "$TUI_RESET"
  fi
  printf '\033[K'
}

tui_progress_done() {
  printf '\n'
}

###############################################################################
# Step tracker — pipeline visualisation
###############################################################################

declare -a _TUI_STEPS=()
declare -a _TUI_STEP_STATUS=()

tui_steps_init() {
  _TUI_STEPS=("$@")
  _TUI_STEP_STATUS=()
  local i
  for i in "${!_TUI_STEPS[@]}"; do
    _TUI_STEP_STATUS[i]="pending"
  done
}

tui_step_active()  { _TUI_STEP_STATUS[$1]="active";  }
tui_step_done()    { _TUI_STEP_STATUS[$1]="done";    }
tui_step_failed()  { _TUI_STEP_STATUS[$1]="failed";  }
tui_step_skipped() { _TUI_STEP_STATUS[$1]="skipped"; }

tui_steps_render() {
  local total=${#_TUI_STEPS[@]}
  local i status icon color label

  echo
  for i in "${!_TUI_STEPS[@]}"; do
    status="${_TUI_STEP_STATUS[$i]}"
    label="${_TUI_STEPS[$i]}"

    case "$status" in
      done)    icon="${TUI_SUCCESS}${ICON_CHECK}${TUI_RESET}"; color="$TUI_SUCCESS" ;;
      active)  icon="${TUI_ACCENT2}${ICON_ARROW}${TUI_RESET}"; color="$TUI_ACCENT2" ;;
      failed)  icon="${TUI_ERROR}${ICON_CROSS}${TUI_RESET}";   color="$TUI_ERROR" ;;
      skipped) icon="${TUI_MUTED}${ICON_RING}${TUI_RESET}";    color="$TUI_MUTED" ;;
      *)       icon="${TUI_MUTED}${ICON_RING}${TUI_RESET}";    color="$TUI_MUTED" ;;
    esac

    printf '  %b  %b%s%b\n' "$icon" "$color" "$label" "$TUI_RESET"

    if (( i < total - 1 )); then
      local next_status="${_TUI_STEP_STATUS[$((i+1))]}"
      local conn_color="$TUI_MUTED"
      [[ "$next_status" == "done" || "$next_status" == "active" ]] && conn_color="$TUI_ACCENT"
      printf '  %b│%b\n' "$conn_color" "$TUI_RESET"
    fi
  done
  echo
}

###############################################################################
# Section header
###############################################################################

tui_section() {
  local title="$1"
  local step="${2:-}"
  local icon="${3:-$ICON_GEAR}"
  local w
  w="$(tui_term_width)"
  local inner=$((w - 4))

  echo
  printf '  %b%s%b' "$TUI_ACCENT" "$BOX_TL" "$TUI_RESET"
  printf '%b' "$TUI_ACCENT"
  _tui_repeat "$BOX_H" "$inner"
  printf '%s%b\n' "$BOX_TR" "$TUI_RESET"

  local left_content="${icon}  ${title}"
  local right_content=""
  [[ -n "$step" ]] && right_content="[ ${step} ]"

  local stripped_left stripped_right
  stripped_left="$(_tui_strip_ansi "$left_content")"
  stripped_right="$(_tui_strip_ansi "$right_content")"

  local pad=$((inner - ${#stripped_left} - ${#stripped_right} - 2))
  (( pad < 0 )) && pad=0

  printf '  %b%s%b ' "$TUI_ACCENT" "$BOX_V" "$TUI_RESET"
  printf '%b%b%s%b' "$TUI_BOLD" "$TUI_WHITE" "$left_content" "$TUI_RESET"
  _tui_repeat ' ' "$pad"
  printf '%b%s%b' "$TUI_MUTED" "$right_content" "$TUI_RESET"
  printf ' %b%s%b\n' "$TUI_ACCENT" "$BOX_V" "$TUI_RESET"

  printf '  %b%s%b' "$TUI_ACCENT" "$BOX_BL" "$TUI_RESET"
  printf '%b' "$TUI_ACCENT"
  _tui_repeat "$BOX_H" "$inner"
  printf '%s%b\n' "$BOX_BR" "$TUI_RESET"
}

###############################################################################
# Animated spinner
###############################################################################

_TUI_SPINNER_PID=""

readonly -a SPIN_DOTS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
readonly -a SPIN_BRAILLE=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
readonly -a SPIN_ARROWS=("←" "↖" "↑" "↗" "→" "↘" "↓" "↙")
readonly -a SPIN_BOUNCE=("⠁" "⠂" "⠄" "⡀" "⢀" "⠠" "⠐" "⠈")
readonly -a SPIN_PULSE=("░" "▒" "▓" "█" "▓" "▒")

tui_spinner_start() {
  local msg="${1:-Working...}"
  local style="${2:-dots}"

  if [[ ! -t 1 ]]; then
    echo "  $msg"
    return
  fi

  (
    set +eEu
    trap 'exit 0' TERM
    trap '' ERR

    local -a frames
    case "$style" in
      braille) frames=("${SPIN_BRAILLE[@]}") ;;
      arrows)  frames=("${SPIN_ARROWS[@]}") ;;
      bounce)  frames=("${SPIN_BOUNCE[@]}") ;;
      pulse)   frames=("${SPIN_PULSE[@]}") ;;
      *)       frames=("${SPIN_DOTS[@]}") ;;
    esac

    local i=0 len=${#frames[@]}
    while true; do
      printf '\r  %b%s%b %s\033[K' \
        "$TUI_ACCENT2" "${frames[$((i % len))]}" "$TUI_RESET" "$msg"
      i=$((i + 1))
      sleep 0.1
    done
  ) &
  _TUI_SPINNER_PID=$!
  disown "$_TUI_SPINNER_PID" 2>/dev/null || true
}

tui_spinner_stop() {
  if [[ -n "${_TUI_SPINNER_PID:-}" ]] && kill -0 "$_TUI_SPINNER_PID" 2>/dev/null; then
    kill "$_TUI_SPINNER_PID" 2>/dev/null || true
    wait "$_TUI_SPINNER_PID" 2>/dev/null || true
    printf '\r\033[K'
  fi
  _TUI_SPINNER_PID=""
}

tui_spin_exec() {
  local msg="$1"; shift
  tui_spinner_start "$msg"
  if "$@"; then
    tui_spinner_stop
    return 0
  else
    local rc=$?
    tui_spinner_stop
    return $rc
  fi
}

###############################################################################
# Interactive prompts
###############################################################################

tui_confirm() {
  local prompt="$1"
  local default="${2:-y}"
  if [[ "$NON_INTERACTIVE" == true ]]; then
    [[ "$default" == "y" ]] && return 0 || return 1
  fi
  local yn hint
  if [[ "$default" == "y" ]]; then
    hint="${TUI_BOLD}Y${TUI_RESET}${TUI_MUTED}/n${TUI_RESET}"
  else
    hint="${TUI_MUTED}y/${TUI_RESET}${TUI_BOLD}N${TUI_RESET}"
  fi
  while true; do
    printf '  %b%s%b %s [%b]: ' "$TUI_ACCENT2" "$ICON_ARROW" "$TUI_RESET" "$prompt" "$hint"
    read -r yn
    yn="${yn:-$default}"
    case "${yn,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     printf '  %b%s  Please answer y or n.%b\n' "$TUI_WARNING" "$ICON_WARN" "$TUI_RESET" ;;
    esac
  done
}

tui_input() {
  local prompt="$1"
  local default="$2"
  local varname="$3"
  if [[ "$NON_INTERACTIVE" == true ]]; then
    printf -v "$varname" '%s' "$default"
    return
  fi
  local value
  printf '  %b%s%b %s [%b%s%b]: ' \
    "$TUI_ACCENT2" "$ICON_ARROW" "$TUI_RESET" \
    "$prompt" \
    "$TUI_MUTED" "$default" "$TUI_RESET"
  read -r value
  value="${value:-$default}"
  printf -v "$varname" '%s' "$value"
}

tui_select() {
  local result_var="$1"; shift
  local prompt="$1"; shift
  local -a options=("$@")
  local count=${#options[@]}

  echo
  printf '  %b%b%s%b\n' "$TUI_BOLD" "$TUI_WHITE" "$prompt" "$TUI_RESET"
  tui_divider "dots"

  local i
  for i in "${!options[@]}"; do
    printf '  %b%s%b  %b%d%b  %s\n' \
      "$TUI_ACCENT" "$ICON_DOT" "$TUI_RESET" \
      "$TUI_BOLD" $((i + 1)) "$TUI_RESET" \
      "${options[$i]}"
  done
  echo

  while true; do
    printf '  %b%s%b Enter choice [1-%d]: ' \
      "$TUI_ACCENT2" "$ICON_ARROW" "$TUI_RESET" "$count"
    local choice
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      printf -v "$result_var" '%s' "${options[$((choice - 1))]}"
      return 0
    fi
    printf '  %b%s  Invalid selection.%b\n' "$TUI_WARNING" "$ICON_WARN" "$TUI_RESET"
  done
}

###############################################################################
# Status line items
###############################################################################

tui_status_line() {
  local label="$1"
  local value="$2"
  local status="${3:-info}"
  local icon color

  case "$status" in
    ok|pass|done) icon="$ICON_CHECK"; color="$TUI_SUCCESS" ;;
    warn)         icon="$ICON_WARN";  color="$TUI_WARNING" ;;
    error|fail)   icon="$ICON_CROSS"; color="$TUI_ERROR" ;;
    skip)         icon="$ICON_RING";  color="$TUI_MUTED" ;;
    active)       icon="$ICON_ARROW"; color="$TUI_ACCENT2" ;;
    *)            icon="$ICON_INFO";  color="$TUI_HIGHLIGHT" ;;
  esac

  printf '  %b%s%b  %-20s %b%s%b\n' \
    "$color" "$icon" "$TUI_RESET" \
    "$label" \
    "$color" "$value" "$TUI_RESET"
}

###############################################################################
# Notification bar
###############################################################################

tui_notify() {
  local msg="$1"
  local level="${2:-info}"
  local color icon

  case "$level" in
    success) color="$TUI_SUCCESS"; icon="$ICON_CHECK" ;;
    warn)    color="$TUI_WARNING"; icon="$ICON_WARN"  ;;
    error)   color="$TUI_ERROR";   icon="$ICON_CROSS" ;;
    *)       color="$TUI_ACCENT2"; icon="$ICON_INFO"  ;;
  esac

  local w
  w="$(tui_term_width)"
  local inner=$((w - 4))

  printf '\n'
  printf '  %b' "$color"
  _tui_repeat "$BOXH_H" "$inner"
  printf '%b\n' "$TUI_RESET"

  printf '  %b%s  %s%b\n' "$color" "$icon" "$msg" "$TUI_RESET"

  printf '  %b' "$color"
  _tui_repeat "$BOXH_H" "$inner"
  printf '%b\n\n' "$TUI_RESET"
}

###############################################################################
# Logging helpers (minimal — matches glados patterns)
###############################################################################

log()     { printf '  %b[INFO]%b  %s\n' "$TUI_MUTED" "$TUI_RESET" "$*"; }
success() { printf '  %b%s  %s%b\n' "$TUI_SUCCESS" "$ICON_CHECK" "$*" "$TUI_RESET"; }
warn()    { printf '  %b%s  %s%b\n' "$TUI_WARNING" "$ICON_WARN" "$*" "$TUI_RESET"; }
err()     { printf '  %b%s  %s%b\n' "$TUI_ERROR" "$ICON_CROSS" "$*" "$TUI_RESET" >&2; }
