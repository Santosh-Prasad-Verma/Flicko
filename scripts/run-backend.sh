#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Flicko — Backend Runner
# ─────────────────────────────────────────────────────────────────────────────
#  Usage:  ./scripts/run-backend.sh
#
#  Loads .env, starts ws-gateway, msg-service, and backend
#  in the background, then waits for Ctrl+C to stop all.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Colours ───────────────────────────────────────────────────────────────────
R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

WHITE=$'\033[97m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
RED=$'\033[91m'
MAGENTA=$'\033[95m'
BLUE=$'\033[94m'
GRAY=$'\033[90m'
BLACK=$'\033[30m'

# 256-colour gradient palette
M=$'\033[38;5;201m'
MP=$'\033[38;5;171m'
P=$'\033[38;5;135m'
PB=$'\033[38;5;99m'
B=$'\033[38;5;63m'
BB=$'\033[38;5;33m'
CB=$'\033[38;5;39m'
C=$'\033[38;5;45m'
X1=$'\033[38;5;51m'
X2=$'\033[38;5;45m'
X3=$'\033[38;5;39m'
X4=$'\033[38;5;33m'
X5=$'\033[38;5;27m'
X6=$'\033[38;5;24m'

BG_DARK=$'\033[48;5;234m'
BG_BLACK=$'\033[40m'
BG_GREEN=$'\033[48;5;22m'
BG_RED=$'\033[48;5;52m'
BG_PURPLE=$'\033[48;5;57m'

# ── Terminal width (hard-capped at 78) ────────────────────────────────────────
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
dbg()  { printf "  ${GRAY}[${R}${MAGENTA}>>${R}${GRAY}]${R}   ${GRAY}%s${R}\n" "$*"; }
hint() { printf "      ${DIM}${GRAY}%s${R}\n"                                  "$*"; }

# ── Section header ────────────────────────────────────────────────────────────
section() {
  local title="$1"
  local rhs=$(( COLS - ${#title} - 9 ))
  [ "$rhs" -lt 1 ] && rhs=1
  gap
  local line="  ${CYAN}$(repeat_char '-' 2)[ ${BOLD}${WHITE}${title}${R}${CYAN} ]$(repeat_char '-' $rhs)${R}"
  printf "%b\n" "$line"
}

# ── Typing animation ──────────────────────────────────────────────────────────
type_text() {
  local text="$1" delay="${2:-0.025}"
  for (( i=0; i<${#text}; i++ )); do
    printf "%s" "${text:$i:1}"
    sleep "$delay"
  done
  printf "\n"
}

# ── Glitch animation ──────────────────────────────────────────────────────────
glitch_text() {
  local text="$1"
  local len=${#text}
  local glitch_chars="@#%&?!"
  for (( round=0; round<5; round++ )); do
    local out=""
    for (( i=0; i<len; i++ )); do
      if (( RANDOM % 3 == 0 )); then
        local gi=$(( RANDOM % ${#glitch_chars} ))
        out+="${RED}${glitch_chars:$gi:1}${R}"
      else
        out+="${text:$i:1}"
      fi
    done
    printf "\r  %b" "$out"
    sleep 0.06
  done
  printf "\r  ${BOLD}${GREEN}%s${R}\n" "$text"
}

# ── Matrix rain ───────────────────────────────────────────────────────────────
matrix_burst() {
  local width=$(( COLS - 4 ))
  local cols_count=6
  local col_width=$(( width / cols_count ))
  local all_cols=()
  for (( c=0; c<cols_count; c++ )); do
    all_cols+=( $(( RANDOM % 6 )) )
  done
  tput civis 2>/dev/null
  for (( row=0; row<7; row++ )); do
    local line="  "
    for (( c=0; c<cols_count; c++ )); do
      local drop=${all_cols[$c]}
      for (( w=0; w<col_width; w++ )); do
        local dist=$(( row - drop ))
        if   (( dist == 0 ));             then line+="${BOLD}${WHITE}"
        elif (( dist > 0 && dist < 3 ));  then line+="${GREEN}"
        elif (( dist >= 3 ));             then line+="${GRAY}${DIM}"
        else                                   line+="${GRAY}${DIM}"
        fi
        local rn=$(( RANDOM % 62 ))
        if   (( rn < 10 )); then line+="$rn"
        elif (( rn < 36 )); then line+="$(printf '%s' "$(printf "\\$(printf '%03o' $(( rn - 10 + 65 )))")")"
        else                     line+="$(printf '%s' "$(printf "\\$(printf '%03o' $(( rn - 36 + 97 )))")")"
        fi
        line+="${R}"
      done
    done
    printf "%b\n" "$line"
    sleep 0.055
    for (( c=0; c<cols_count; c++ )); do
      if (( RANDOM % 2 == 0 )); then
        all_cols[$c]=$(( all_cols[$c] + 1 ))
      fi
    done
  done
  tput cnorm 2>/dev/null
}

# ── Flicko wordmark renderer ─────────────────────────────────────────────────
render_flicko_wordmark() {
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

  sleep 0.12

  local sweep_cols=("$X1" "$X2" "$X3" "$X4" "$X5" "$X6" \
                    "$X2" "$X3" "$X4" "$X5" "$X6" "$X5" \
                    "$X1" "$X2" "$X3" "$X4" "$X5" "$X6")

  for (( sw=0; sw<2; sw++ )); do
    for (( l=0; l<num_lines; l++ )); do
      tput cuu1 2>/dev/null
    done
    for (( l=0; l<num_lines; l++ )); do
      local ci=$(( (sw * 3 + l) % ${#sweep_cols[@]} ))
      printf "\r%b%s%b\n" "${sweep_cols[$ci]}${BOLD}" "${raw[$l]}" "${R}"
    done
    sleep 0.08
  done

  for (( l=0; l<num_lines; l++ )); do
    tput cuu1 2>/dev/null
  done
  for (( l=0; l<num_lines; l++ )); do
    printf "\r%b%s%b\n" "${line_cols[$l]}${BOLD}" "${raw[$l]}" "${R}"
  done
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

# ── Progress bar ──────────────────────────────────────────────────────────────
progress_bar() {
  local current="$1" total="$2"
  local bar_w=38
  local filled=$(( current * bar_w / total ))
  local empty=$(( bar_w - filled ))
  local pct=$(( current * 100 / total ))
  printf "  ${GRAY}[${R}"
  printf "${GREEN}$(repeat_char '=' $filled)${R}"
  printf "${GRAY}$(repeat_char '.' $empty)${R}"
  printf "${GRAY}]${R}  ${BOLD}${WHITE}%3d%%${R}  ${GRAY}(%d/%d)${R}\n" \
    "$pct" "$current" "$total"
}

# ── Pulse animation (for service start) ──────────────────────────────────────
pulse_start() {
  local name="$1" port="$2" pid="$3"
  local frames=('-' '+' '*' '+' '-')
  tput civis 2>/dev/null
  for f in "${frames[@]}"; do
    printf "\r  ${GREEN}[%s]${R}   ${BOLD}${WHITE}%s${R}  ${GRAY}:%s${R}  ${GRAY}pid:${CYAN}%s${R}   " \
      "$f" "$name" "$port" "$pid"
    sleep 0.08
  done
  printf "\r"
  ok "${BOLD}${WHITE}${name}${R}  ${GRAY}port:${CYAN}${port}${R}  ${GRAY}pid:${CYAN}${pid}${R}"
  tput cnorm 2>/dev/null
}

# ── Live service status table ─────────────────────────────────────────────────
print_status_table() {
  local ws_pid="$1" msg_pid="$2" be_pid="$3"
  local ws_port="${WS_PORT:-8080}"
  local msg_port="${HTTP_PORT:-8085}"
  local be_port="${PORT:-8081}"
  local w=$(( COLS - 4 ))

  gap
  printf "  ${GRAY}+$(repeat_char '-' $(( w - 2 )))+${R}\n"
  printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-12s${R}  ${GRAY}|${R}  ${WHITE}%-20s${R}  ${GRAY}|${R}  ${GREEN}%-6s${R}  ${GRAY}|${R}  ${CYAN}%-5s${R}  ${GRAY}|${R}\n" \
    "SERVICE" "ADDRESS" "STATUS" "PID"
  printf "  ${GRAY}+$(repeat_char '-' $(( w - 2 )))+${R}\n"
  printf "  ${GRAY}|${R}  ${BB}${BOLD}%-12s${R}  ${GRAY}|${R}  ${WHITE}%-20s${R}  ${GRAY}|${R}  ${GREEN}%-6s${R}  ${GRAY}|${R}  ${CYAN}%-5s${R}  ${GRAY}|${R}\n" \
    "ws-gateway" "ws://localhost:${ws_port}" "UP" "${ws_pid}"
  printf "  ${GRAY}|${R}  ${BB}${BOLD}%-12s${R}  ${GRAY}|${R}  ${WHITE}%-20s${R}  ${GRAY}|${R}  ${GREEN}%-6s${R}  ${GRAY}|${R}  ${CYAN}%-5s${R}  ${GRAY}|${R}\n" \
    "msg-service" "http://localhost:${msg_port}" "UP" "${msg_pid}"
  printf "  ${GRAY}|${R}  ${BB}${BOLD}%-12s${R}  ${GRAY}|${R}  ${WHITE}%-20s${R}  ${GRAY}|${R}  ${GREEN}%-6s${R}  ${GRAY}|${R}  ${CYAN}%-5s${R}  ${GRAY}|${R}\n" \
    "backend" "http://localhost:${be_port}" "UP" "${be_pid}"
  printf "  ${GRAY}+$(repeat_char '-' $(( w - 2 )))+${R}\n"
  gap
}

# ─────────────────────────────────────────────────────────────────────────────
#  BOOT ANIMATION
# ─────────────────────────────────────────────────────────────────────────────
boot_sequence() {
  clear
  tput civis 2>/dev/null
  local w=$(( COLS - 4 ))

  # ── Phase 1: scan lines ───────────────────────────────────────────────────
  for (( i=0; i<3; i++ )); do
    local line=""
    for (( j=0; j<w; j++ )); do
      local rn=$(( RANDOM % 62 ))
      if   (( rn < 10 )); then line+="$rn"
      elif (( rn < 36 )); then
        local code=$(( rn - 10 + 65 ))
        line+="$(printf "\\$(printf '%03o' $code)")"
      else
        local code=$(( rn - 36 + 97 ))
        line+="$(printf "\\$(printf '%03o' $code)")"
      fi
    done
    printf "  ${GREEN}${DIM}%s${R}\n" "$line"
    sleep 0.04
  done
  gap

  # ── Phase 2: BIOS-style boot messages ────────────────────────────────────
  local bios_lines=(
    "${GRAY}FLICKO-BIOS v2.1.0  |  64MB VRAM  |  CPU: BACKEND-CORE x3${R}"
    "${GRAY}Detecting project root...       ${GREEN}OK${R}"
    "${GRAY}Scanning environment file...    ${GREEN}OK${R}"
    "${GRAY}Checking Go toolchain...        ${GREEN}OK${R}"
    "${GRAY}Initialising service map...     ${GREEN}OK${R}"
  )
  for bl in "${bios_lines[@]}"; do
    printf "  "
    printf "%b\n" "$bl"
    sleep 0.12
  done
  gap

  # ── Phase 3: segmented progress bar ──────────────────────────────────────
  local phases=("ENV      " "REDIS    " "JWT      " "SERVICES " "LAUNCH   ")
  local phase_colours=("$M" "$P" "$B" "$CB" "$GREEN")
  local bar_w=$(( w - 20 ))
  local total_phases=${#phases[@]}

  for (( p=0; p<total_phases; p++ )); do
    local label="${phases[$p]}"
    local col="${phase_colours[$p]}"
    local steps=$(( bar_w / total_phases ))
    local start=$(( p * steps ))
    local end=$(( start + steps ))
    [ "$p" -eq $(( total_phases - 1 )) ] && end=$bar_w

    for (( s=start; s<=end; s++ )); do
      local empty=$(( bar_w - s ))
      local pct=$(( s * 100 / bar_w ))
      local bar=""
      for (( b=0; b<s; b++ )); do
        local seg=$(( b * total_phases / bar_w ))
        bar+="${phase_colours[$seg]}|${R}"
      done
      printf "\r  ${col}${BOLD}[%s]${R}  [%b${GRAY}$(repeat_char '.' $empty)${R}]  ${BOLD}${WHITE}%3d%%${R}" \
        "$label" "$bar" "$pct"
      sleep 0.011
    done
  done
  printf "\n"
  gap

  # ── Phase 4: flicker flash then clear ────────────────────────────────────
  for (( f=0; f<2; f++ )); do
    printf "  ${GREEN}${BOLD}[ FLICKO BACKEND RUNNER — GO ]${R}\n"
    sleep 0.07
    tput cuu1 2>/dev/null
    printf "%${COLS}s\r" ""
    sleep 0.05
  done
  printf "  ${GREEN}${BOLD}[ FLICKO BACKEND RUNNER — GO ]${R}\n"
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
matrix_burst
gap

# ── Top border ────────────────────────────────────────────────────────────────
printf "  ${CYAN}$(repeat_char '=' $(( COLS - 4 )))${R}\n"
gap

# ── Flicko icon logo ──────────────────────────────────────────────────────────
ICON_LINES=(
  "       ${BB}▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${C}▄▄▄▄▄▄▄▄"
  "       ${M}▄▄▄▄▄▄▄▄${MP}▄▄▄▄${P}▄▄${PB}██████${B}████████${BB}████████████▄"
  "       ${M}████████${MP}████${P}██${PB}██████${B}██████${BB}██████${C}████████▄"
  "       ${M}▀▀▀▀▀▀▀▀${MP}▀▀▀▀${P}▀▀${PB}█████${B}██████${BB}██████${C}██████████"
  "                         ${PB}█████${B}██████${BB}██████${C}██████████"
  "       ${M}▄▄▄▄▄▄▄▄▄▄▄▄${MP}▄▄▄▄${PB}██████${B}████${BB}██████${C}█████████"
  "       ${M}████████████${MP}████${PB}██████${B}████${BB}██████${C}████████"
  "       ${M}▀▀▀▀▀▀▀▀▀▀${MP}▀▀${P}██████${PB}██████${B}██████${BB}██████▀"
  "       ${M}▄▄▄▄▄▄▄▄${MP}▄▄${P}████████${PB}██████${B}████████${BB}██▀"
  "       ${M}████████${MP}██${P}████████${PB}██████${B}██████▀▀"
  "       ${M}▀▀▀▀▀▀▀▀${MP}▀▀${P}▀▀████${PB}██████${B}████▀"
  "                    ${P}██${PB}████${B}████▀▀"
  "                     ${PB}██${B}██▀"
  "                      ${PB}▀▀"
)

for line in "${ICON_LINES[@]}"; do
  printf "${BOLD}%b\n" "$line"
done

gap

# ── Word-mark logo ────────────────────────────────────────────────────────────
render_flicko_wordmark

gap

# ── Sub-title ─────────────────────────────────────────────────────────────────
SUBTITLE="[ BACKEND RUNNER  *  GO SERVICES  *  LOCAL DEV  *  v1.0.0 ]"
SUB_PAD=$(( (COLS - ${#SUBTITLE}) / 2 ))
[ "$SUB_PAD" -lt 0 ] && SUB_PAD=0
printf "%${SUB_PAD}s${GRAY}%s${R}\n" "" "$SUBTITLE"

gap

# ── Timestamp badge ───────────────────────────────────────────────────────────
BADGE="  >> flicko-runner  |  $(date '+%Y-%m-%d %H:%M:%S')  "
BADGE_PAD=$(( (COLS - ${#BADGE}) / 2 ))
[ "$BADGE_PAD" -lt 0 ] && BADGE_PAD=0
printf "%${BADGE_PAD}s${BG_DARK}${CYAN}${BOLD}%s${R}\n" "" "$BADGE"

gap
printf "  ${CYAN}$(repeat_char '=' $(( COLS - 4 )))${R}\n"

tput cnorm 2>/dev/null

# ─────────────────────────────────────────────────────────────────────────────
#  ENVIRONMENT
# ─────────────────────────────────────────────────────────────────────────────
section "ENVIRONMENT"
gap

start_spinner "Locating .env file..."
sleep 0.3
stop_spinner

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  ok "Found .env at ${PROJECT_ROOT}/.env"
  start_spinner "Loading environment variables..."
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"
  set +a
  stop_spinner
  ok "Environment loaded"
else
  stop_spinner
  fail ".env not found at ${PROJECT_ROOT}/.env"
  gap
  hint "Copy the template:  cp .env.example .env"
  hint "Then fill in your secrets and re-run"
  gap
  exit 1
fi

# ── Defaults ──────────────────────────────────────────────────────────────────
export REDIS_URL="${REDIS_URL:-redis://localhost:6379}"
export JWT_PUBLIC_KEY_PATH="${JWT_PUBLIC_KEY_PATH:-${PROJECT_ROOT}/secrets/jwt_public.pem}"

gap
dbg "REDIS_URL            = ${REDIS_URL}"
dbg "JWT_PUBLIC_KEY_PATH  = ${JWT_PUBLIC_KEY_PATH}"
dbg "DATABASE_URL         = ${DATABASE_URL:+[set]}"

# ─────────────────────────────────────────────────────────────────────────────
#  JWT KEY CHECK
# ─────────────────────────────────────────────────────────────────────────────
section "JWT KEYS"
gap

start_spinner "Checking JWT keypair..."
sleep 0.25
stop_spinner

if [[ ! -f "${JWT_PUBLIC_KEY_PATH}" ]]; then
  warn "JWT public key not found — generating local keypair..."
  hint "Path: ${JWT_PUBLIC_KEY_PATH}"
  gap
  start_spinner "Running generate-jwt-keys.sh..."
  "${PROJECT_ROOT}/scripts/generate-jwt-keys.sh" --force >/dev/null
  export JWT_PUBLIC_KEY_PATH="${PROJECT_ROOT}/secrets/jwt_public.pem"
  stop_spinner
  ok "JWT keys generated under ${PROJECT_ROOT}/secrets"
else
  ok "JWT public key found at ${JWT_PUBLIC_KEY_PATH}"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  DATABASE CHECK
# ─────────────────────────────────────────────────────────────────────────────
section "DATABASE"
gap

start_spinner "Validating DATABASE_URL..."
sleep 0.25
stop_spinner

if [[ -z "${DATABASE_URL:-}" ]]; then
  fail "DATABASE_URL is not set — msg-service requires PostgreSQL"
  gap
  hint "Set it in .env or export before running. Example:"
  hint "  DATABASE_URL=postgresql://user:pass@host:5432/db?sslmode=require"
  hint "If you use Supabase, copy the pooler URI into DATABASE_URL"
  gap
  exit 1
fi

ok "DATABASE_URL is set"
hint "$(printf '%s' "$DATABASE_URL" | sed 's|//.*@|//***:***@|')"

# ─────────────────────────────────────────────────────────────────────────────
#  REDIS CHECK
# ─────────────────────────────────────────────────────────────────────────────
section "REDIS"
gap

if [[ "${REDIS_URL}" =~ ^redis://localhost ]] || \
   [[ "${REDIS_URL}" =~ ^redis://127\.0\.0\.1 ]]; then

  start_spinner "Pinging local Redis at ${REDIS_URL}..."
  sleep 0.2
  stop_spinner

  if command -v redis-cli >/dev/null 2>&1; then
    if redis-cli -u "${REDIS_URL}" ping &>/dev/null; then
      ok "Local Redis is reachable"
    else
      warn "Cannot reach Redis at ${REDIS_URL}"
      gap

      if command -v redis-server >/dev/null 2>&1; then
        start_spinner "Attempting to start redis-server (daemon mode)..."
        if redis-server --daemonize yes >/dev/null 2>&1; then
          sleep 1
          stop_spinner
          if redis-cli -u "${REDIS_URL}" ping &>/dev/null; then
            ok "Local Redis started successfully"
          else
            stop_spinner
            fail "redis-server started but ${REDIS_URL} is still unreachable"
            hint "Check redis logs or start manually"
            hint "Or use Docker:  docker compose -f docker-compose.zero.yml up -d redis"
            gap
            exit 1
          fi
        else
          stop_spinner
          fail "Could not start redis-server automatically"
          hint "Start manually or use Docker:"
          hint "  docker compose -f docker-compose.zero.yml up -d redis"
          gap
          exit 1
        fi
      else
        fail "redis-server not installed"
        hint "Start with Docker:  docker compose -f docker-compose.zero.yml up -d redis"
        gap
        exit 1
      fi
    fi
  else
    warn "redis-cli not installed — skipping active ping check"
    hint "Install redis-tools to enable the health check"
  fi

else
  info "Remote Redis detected — skipping local ping"
  dbg  "REDIS_URL = ${REDIS_URL}"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  PIDs + CLEANUP TRAP
# ─────────────────────────────────────────────────────────────────────────────
WS_PID=""
MSG_PID=""
BACKEND_PID=""

cleanup() {
  printf "\n"
  section "SHUTDOWN"
  gap
  info "Terminating services gracefully..."
  gap

  if [[ -n "$WS_PID" ]]; then
    start_spinner "Stopping ws-gateway (pid: ${WS_PID})..."
    kill "$WS_PID" 2>/dev/null || true
    sleep 0.3
    stop_spinner
    ok "ws-gateway stopped"
  fi

  if [[ -n "$MSG_PID" ]]; then
    start_spinner "Stopping msg-service (pid: ${MSG_PID})..."
    kill "$MSG_PID" 2>/dev/null || true
    sleep 0.3
    stop_spinner
    ok "msg-service stopped"
  fi

  if [[ -n "$BACKEND_PID" ]]; then
    start_spinner "Stopping backend (pid: ${BACKEND_PID})..."
    kill "$BACKEND_PID" 2>/dev/null || true
    sleep 0.3
    stop_spinner
    ok "backend stopped"
  fi

  gap
  glitch_text "All services terminated — session closed"
  gap
  printf "  ${CYAN}$(repeat_char '=' $(( COLS - 4 )))${R}\n"
  gap
  exit 0
}

trap cleanup SIGINT SIGTERM

# ─────────────────────────────────────────────────────────────────────────────
#  LAUNCH SERVICES
# ─────────────────────────────────────────────────────────────────────────────
section "LAUNCHING SERVICES"
gap

# ── ws-gateway ────────────────────────────────────────────────────────────────
dbg "Spawning ws-gateway..."
progress_bar 0 3
start_spinner "Compiling and starting ws-gateway on :${WS_PORT:-8080}..."
cd "${PROJECT_ROOT}/services/ws-gateway"
go run ./cmd/gateway &
WS_PID=$!
sleep 2
stop_spinner
progress_bar 1 3
pulse_start "ws-gateway" "${WS_PORT:-8080}" "$WS_PID"
gap

# ── msg-service ───────────────────────────────────────────────────────────────
dbg "Spawning msg-service..."
start_spinner "Compiling and starting msg-service on :${HTTP_PORT:-8085}..."
cd "${PROJECT_ROOT}/services/msg-service"
go run ./cmd/server &
MSG_PID=$!
sleep 2
stop_spinner
progress_bar 2 3
pulse_start "msg-service" "${HTTP_PORT:-8085}" "$MSG_PID"
gap

# ── backend ───────────────────────────────────────────────────────────────────
dbg "Spawning backend..."
start_spinner "Compiling and starting backend on :${PORT:-8081}..."
cd "${PROJECT_ROOT}/backend"
go run ./cmd/server &
BACKEND_PID=$!
sleep 2
stop_spinner
progress_bar 3 3
pulse_start "backend" "${PORT:-8081}" "$BACKEND_PID"

# ─────────────────────────────────────────────────────────────────────────────
#  STATUS TABLE + HOLD
# ─────────────────────────────────────────────────────────────────────────────
gap
glitch_text "All services online — Flicko backend is live"

print_status_table "$WS_PID" "$MSG_PID" "$BACKEND_PID"

printf "  ${BG_GREEN}${BOLD}${WHITE}  [OK]  All 3 services running — press Ctrl+C to stop  ${R}\n"
gap
printf "  ${CYAN}$(repeat_char '=' $(( COLS - 4 )))${R}\n"
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
printf "  ${CYAN}$(repeat_char '=' $(( COLS - 4 )))${R}\n"
gap

# ─────────────────────────────────────────────────────────────────────────────
#  WAIT — keep alive until Ctrl+C
# ─────────────────────────────────────────────────────────────────────────────
wait
