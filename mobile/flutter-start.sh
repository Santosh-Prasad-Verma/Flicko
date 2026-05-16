#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────────────────
#  flutter-start.sh — Flutter Development Launcher
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ── Dynamic Path Detection ───────────────────────────────────────────────────
# If flutter is not in PATH, try to find it in common locations
if ! command -v flutter &> /dev/null; then
  # Check for flutter in home directory (common in this environment)
  if [ -d "$HOME/flutter/bin" ]; then
    export PATH="$PATH:$HOME/flutter/bin"
  elif [ -d "$HOME/development/flutter/bin" ]; then
    export PATH="$PATH:$HOME/development/flutter/bin"
  fi
fi

# ── Colours ───────────────────────────────────────────────────────────────────
R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

WHITE=$'\033[97m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
RED=$'\033[91m'
BLUE=$'\033[94m'
MAGENTA=$'\033[95m'
GRAY=$'\033[90m'

# 256-colour gradient palette
X1=$'\033[38;5;51m'
X2=$'\033[38;5;45m'
X3=$'\033[38;5;39m'
X4=$'\033[38;5;33m'
X5=$'\033[38;5;27m'
X6=$'\033[38;5;24m'

BG_PURPLE=$'\033[48;5;57m'
BG_DARK=$'\033[48;5;234m'
BG_GREEN=$'\033[48;5;22m'
BG_RED=$'\033[48;5;52m'

# ── Terminal width ─────────────────────────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 72)
[ "$COLS" -gt 78 ] && COLS=78

# ── Core helpers ──────────────────────────────────────────────────────────────
gap() { printf "\n"; }

repeat_char() {
  local char="$1" count="$2" out=""
  for (( i=0; i<count; i++ )); do out+="$char"; done
  printf "%s" "$out"
}

# ── Status lines ──────────────────────────────────────────────────────────────
ok()   { printf "  ${GREEN}[${BOLD}OK${R}${GREEN}]${R}   ${WHITE}%s${R}\n"    "$*"; }
fail() { printf "  ${RED}[${BOLD}!!${R}${RED}]${R}   ${WHITE}%s${R}\n"        "$*"; }
warn() { printf "  ${YELLOW}[${BOLD}WW${R}${YELLOW}]${R}   ${YELLOW}%s${R}\n" "$*"; }
info() { printf "  ${GRAY}[${R}${CYAN}--${R}${GRAY}]${R}   ${GRAY}%s${R}\n"   "$*"; }

# ── Section header ────────────────────────────────────────────────────────────
section() {
  local title="$1"
  local rhs=$(( COLS - ${#title} - 9 ))
  [ "$rhs" -lt 1 ] && rhs=1
  gap
  printf "  ${CYAN}$(repeat_char '─' 2)[ ${BOLD}${WHITE}${title}${R}${CYAN} ]$(repeat_char '─' $rhs)${R}\n"
}

# ── Spinner ───────────────────────────────────────────────────────────────────
SPINNER_PID=""

start_spinner() {
  local msg="$1"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  (
    local i=0
    tput civis 2>/dev/null
    while true; do
      printf "\r  ${GREEN}${frames[$i]}${R}  ${GRAY}${msg}${R}   "
      i=$(( (i + 1) % ${#frames[@]} ))
      sleep 0.07
    done
  ) &
  SPINNER_PID=$!
  disown "$SPINNER_PID" 2>/dev/null
}

stop_spinner() {
  if [ -n "$SPINNER_PID" ]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf "\r%${COLS}s\r" ""
    tput cnorm 2>/dev/null
  fi
}

# ── Banner ───────────────────────────────────────────────────────────────────
render_flutter_wordmark() {
  local raw=(
    "  ███████╗  ██╗      ██╗   ██████╗  ██╗  ██╗   ██████╗"
    "  ██╔════╝  ██║      ██║  ██╔════╝  ██║ ██╔╝  ██╔═══██╗"
    "  █████╗    ██║      ██║  ██║       █████╔╝   ██║   ██║"
    "  ██╔══╝    ██║      ██║  ██║       ██╔═██╗   ██║   ██║"
    "  ██║       ███████╗ ██║  ╚██████╗  ██║  ╚██╗ ╚██████╔╝"
    "  ╚═╝       ╚══════╝ ╚═╝   ╚═════╝  ╚═╝   ╚══╝  ╚═════╝"
  )
  local line_cols=("$X2" "$X3" "$X4" "$X5" "$X6" "$GRAY")
  local num_lines=${#raw[@]}

  for (( l=0; l<num_lines; l++ )); do
    printf "%b%s%b\n" "${line_cols[$l]}${BOLD}" "${raw[$l]}" "${R}"
  done
}

# ── Boot sequence ─────────────────────────────────────────────────────────────
boot_sequence() {
  clear
  tput civis 2>/dev/null
  gap

  local bios_lines=(
    "${GRAY}FLICKO-FLUTTER v1.0.0  |  DART SDK  |  HOT RELOAD ENABLED${R}"
    "${GRAY}Detecting terminal geometry...  ${GREEN}OK${R}"
    "${GRAY}Loading Flutter toolchain...     ${GREEN}OK${R}"
    "${GRAY}Initialising device manager...   ${GREEN}OK${R}"
  )
  for bl in "${bios_lines[@]}"; do
    printf "  "
    printf "%b\n" "$bl"
    sleep 0.08
  done
  gap

  printf "  ${GREEN}${BOLD}[ FLUTTER LAUNCHER — READY ]${R}\n"
  sleep 0.3
  tput cnorm 2>/dev/null
  sleep 0.2
  clear
}

# ─────────────────────────────────────────────────────────────────────────────
#  RUN BOOT
# ─────────────────────────────────────────────────────────────────────────────
boot_sequence

# ─────────────────────────────────────────────────────────────────────────────
#  MAIN SCREEN
# ─────────────────────────────────────────────────────────────────────────────
tput civis 2>/dev/null
gap

printf "  ${CYAN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"
gap

render_flutter_wordmark

gap

SUBTITLE="[ FLUTTER  *  DART  *  HOT RELOAD  *  DEVELOPER EDITION  *  v1.0 ]"
SUB_PAD=$(( (COLS - ${#SUBTITLE}) / 2 ))
[ "$SUB_PAD" -lt 0 ] && SUB_PAD=0
printf "%${SUB_PAD}s${GRAY}%s${R}\n" "" "$SUBTITLE"

gap

BADGE="  >> flutter-start v1.0  |  $(date '+%Y-%m-%d %H:%M:%S')  "
BADGE_PAD=$(( (COLS - ${#BADGE}) / 2 ))
[ "$BADGE_PAD" -lt 0 ] && BADGE_PAD=0
printf "%${BADGE_PAD}s${BG_DARK}${CYAN}${BOLD}%s${R}\n" "" "$BADGE"

gap
printf "  ${CYAN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"

tput cnorm 2>/dev/null

# ─────────────────────────────────────────────────────────────────────────────
#  ENVIRONMENT CHECK
# ─────────────────────────────────────────────────────────────────────────────
section "SYSTEM ENVIRONMENT"
gap

start_spinner "Probing environment..."

FLUTTER_VER=$(flutter --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "not found")
DART_VER=$(dart --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "not found")
OS_STR="$(uname -s) $(uname -r | cut -d- -f1)"

stop_spinner

TABLE_INNER=$(( COLS - 4 ))
printf "  ${GRAY}+$(repeat_char '─' 16)+$(repeat_char '─' $(( TABLE_INNER - 19 )))+${R}\n"
printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-14s${R}  ${GRAY}|${R}  ${CYAN}${BOLD}%-*s${R}  ${GRAY}|${R}\n" \
  "KEY" "$(( TABLE_INNER - 23 ))" "VALUE"
printf "  ${GRAY}+$(repeat_char '─' 16)+$(repeat_char '─' $(( TABLE_INNER - 19 )))+${R}\n"

kv() {
  local key="$1" val="$2"
  printf "  ${GRAY}│${R}  ${CYAN}${BOLD}%-14s${R}  ${GRAY}│${R}  ${WHITE}%-*s${R}  ${GRAY}│${R}\n" \
    "$key" "$(( COLS - 28 ))" "$val"
}

kv "Project"   "$(basename "$SCRIPT_DIR")"
kv "Path"      "$SCRIPT_DIR"
kv "Flutter"   "$FLUTTER_VER"
kv "Dart"      "$DART_VER"
kv "Shell"     "$(basename "$SHELL")"
kv "OS"        "$OS_STR"

printf "  ${GRAY}+$(repeat_char '─' 16)+$(repeat_char '─' $(( TABLE_INNER - 19 )))+${R}\n"

gap
[ "$FLUTTER_VER" != "not found" ] && ok "Flutter reachable  ${GRAY}(${FLUTTER_VER})${R}" \
                                       || fail "Flutter NOT found in PATH"
[ "$DART_VER" != "not found" ] && ok "Dart reachable  ${GRAY}(${DART_VER})${R}" \
                                   || fail "Dart NOT found in PATH"

# ─────────────────────────────────────────────────────────────────────────────
#  DEVICE DETECTION
# ─────────────────────────────────────────────────────────────────────────────
section "AVAILABLE DEVICES"
gap

start_spinner "Scanning for Flutter devices..."
sleep 0.5
DEVICES_OUT=$(flutter devices 2>&1)
stop_spinner

echo "$DEVICES_OUT" | head -20

gap

# Check if any devices are available
if ! echo "$DEVICES_OUT" | grep -q "No connected devices"; then
  ok "Flutter devices detected"
else
  warn "No devices detected - will use web or add device with --device flag"
fi

gap

# ─────────────────────────────────────────────────────────────────────────────
#  BUILD OPTIONS
# ─────────────────────────────────────────────────────────────────────────────
section "BUILD OPTIONS"
gap

info "Available build modes:"
info "  ${CYAN}flutter run${R}           - Run on connected device (default)"
info "  ${CYAN}flutter run --release${R} - Run in release mode"
info "  ${CYAN}flutter run --profile${R} - Run in profile mode"
info "  ${CYAN}flutter run -d chrome${R}  - Run on Chrome (web)"
info "  ${CYAN}flutter run -d <id>${R}    - Run on specific device ID"
gap

# Parse command line arguments
BUILD_MODE="debug"
DEVICE_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --release)
      BUILD_MODE="release"
      shift
      ;;
    --profile)
      BUILD_MODE="profile"
      shift
      ;;
    -d|--device)
      DEVICE_ID="$2"
      shift 2
      ;;
    -d=*|--device=*)
      DEVICE_ID="${1#*=}"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
#  LAUNCH
# ─────────────────────────────────────────────────────────────────────────────
section "LAUNCH"
gap

if [ "$BUILD_MODE" = "debug" ]; then
  info "Starting in ${BOLD}DEBUG${R} mode with hot reload"
elif [ "$BUILD_MODE" = "release" ]; then
  info "Starting in ${BOLD}RELEASE${R} mode"
else
  info "Starting in ${BOLD}PROFILE${R} mode"
fi

gap

BUILD_ARGS=(flutter run)
BUILD_DISPLAY_ARGS=(flutter run)

if [ "$BUILD_MODE" != "debug" ]; then
  BUILD_ARGS+=("--$BUILD_MODE")
  BUILD_DISPLAY_ARGS+=("--$BUILD_MODE")
fi

if [ -n "$DEVICE_ID" ]; then
  BUILD_ARGS+=("-d" "$DEVICE_ID")
  BUILD_DISPLAY_ARGS+=("-d" "$DEVICE_ID")
  info "Target device: ${CYAN}${DEVICE_ID}${R}"
fi

DART_DEFINE_KEYS=(
  FLICKO_SUPABASE_URL
  FLICKO_SUPABASE_ANON_KEY
  FLICKO_LIVEKIT_URL
  FLICKO_STRIPE_PUBLISHABLE_KEY
  FLICKO_API_URL
  FLICKO_GIPHY_API_KEY
  FLICKO_APPWRITE_PROJECT_ID
  FLICKO_APPWRITE_PROJECT_NAME
  FLICKO_APPWRITE_PUBLIC_ENDPOINT
  FLICKO_APPWRITE_BUCKET_ID
  SUPABASE_URL
  SUPABASE_ANON_KEY
  LIVEKIT_URL
  STRIPE_PUBLISHABLE_KEY
  API_BASE_URL
  GIPHY_API_KEY
  APPWRITE_PROJECT_ID
  APPWRITE_PROJECT_NAME
  APPWRITE_PUBLIC_ENDPOINT
  APPWRITE_BUCKET_ID
)

DART_DEFINE_COUNT=0
for key in "${DART_DEFINE_KEYS[@]}"; do
  if [ -n "${!key:-}" ]; then
    BUILD_ARGS+=("--dart-define=$key=${!key}")
    DART_DEFINE_COUNT=$((DART_DEFINE_COUNT + 1))
  fi
done

if [ "$DART_DEFINE_COUNT" -gt 0 ]; then
  info "Passing ${CYAN}${DART_DEFINE_COUNT}${R}${GRAY} Dart defines from environment"
  BUILD_DISPLAY_ARGS+=("--dart-define=<${DART_DEFINE_COUNT} env values>")
fi

BUILD_CMD_DISPLAY=""
for arg in "${BUILD_DISPLAY_ARGS[@]}"; do
  printf -v quoted "%q" "$arg"
  BUILD_CMD_DISPLAY+="$quoted "
done
BUILD_CMD_DISPLAY="${BUILD_CMD_DISPLAY% }"

gap
printf "  ${GREEN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"
gap
printf "  ${BOLD}${GREEN}>>  ${R}"
printf "${CYAN}${BOLD}%s${R}\n" "$BUILD_CMD_DISPLAY"
gap
printf "  ${GRAY}Keybindings:  ${CYAN}r${R}${GRAY} hot reload  |  ${CYAN}R${R}${GRAY} hot restart  |  ${CYAN}q${R}${GRAY} quit${R}\n"
gap
printf "  ${GREEN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"
gap

# ─────────────────────────────────────────────────────────────────────────────
#  FOOTER
# ─────────────────────────────────────────────────────────────────────────────
REPO="https://github.com/Santosh-Prasad-Verma/Flicko"
REPO_PAD=$(( (COLS - ${#REPO} - 5) / 2 ))
[ "$REPO_PAD" -lt 0 ] && REPO_PAD=0
printf "%${REPO_PAD}s${GRAY}[*]  ${CYAN}${BOLD}%s${R}\n" "" "$REPO"

gap

CREDIT="Made with  <3  by the Flicko team"
CREDIT_PAD=$(( (COLS - ${#CREDIT}) / 2 ))
[ "$CREDIT_PAD" -lt 0 ] && CREDIT_PAD=0
printf "%${CREDIT_PAD}s${GRAY}%s${R}\n" "" "$CREDIT"

gap
printf "  ${CYAN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"
gap

# ─────────────────────────────────────────────────────────────────────────────
#  EXECUTE
# ─────────────────────────────────────────────────────────────────────────────
cd "$SCRIPT_DIR" || exit 1
"${BUILD_ARGS[@]}"
FLUTTER_STATUS=$?
exit "$FLUTTER_STATUS"
