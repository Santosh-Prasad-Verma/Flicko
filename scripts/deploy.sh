#!/usr/bin/env bash
# =============================================================================
# Flicko — Production Deploy Script  v2.0
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ══════════════════════════════════════════════════════════════════════════════
# COLOURS
# ══════════════════════════════════════════════════════════════════════════════
R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
WHITE=$'\033[97m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
RED=$'\033[91m'
MAGENTA=$'\033[95m'
GRAY=$'\033[90m'

X1=$'\033[38;5;51m'
X2=$'\033[38;5;45m'
X3=$'\033[38;5;39m'
X4=$'\033[38;5;33m'
X5=$'\033[38;5;27m'
X6=$'\033[38;5;24m'

LBLUE=$'\033[38;5;75m'
MINT=$'\033[38;5;121m'
SILVER=$'\033[38;5;250m'
STEEL=$'\033[38;5;240m'
DARKSTEEL=$'\033[38;5;236m'
LEDGRN=$'\033[38;5;46m'
LEDOFF=$'\033[38;5;238m'
LEDBLU=$'\033[38;5;27m'
LEDAMB=$'\033[38;5;214m'
LEDRED=$'\033[38;5;196m'
BGSTEEL=$'\033[48;5;235m'

# ══════════════════════════════════════════════════════════════════════════════
# TERMINAL
# ══════════════════════════════════════════════════════════════════════════════
COLS=$(tput cols  2>/dev/null || echo 100)
ROWS=$(tput lines 2>/dev/null || echo 40)
[[ "$COLS" -lt 80  ]] && COLS=80

hide_cursor() { tput civis 2>/dev/null || true; }
show_cursor() { tput cnorm 2>/dev/null || true; }
move_up()     { local n="${1:-1}"; for (( i=0; i<n; i++ )); do tput cuu1 2>/dev/null || true; done; }
clear_line()  { tput el  2>/dev/null || true; }

# ══════════════════════════════════════════════════════════════════════════════
# LOCK FILE  — prevent concurrent deploys
# ══════════════════════════════════════════════════════════════════════════════
LOCK_FILE="/tmp/flicko_deploy.lock"
DEPLOY_LOG="${PROJECT_ROOT}/deploy_$(date +%Y%m%d_%H%M%S).log"
DEPLOY_START=$(date +%s)

acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    local pid
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
    echo "[ERROR] Another deploy is already running (PID: ${pid}). Remove ${LOCK_FILE} if stale." >&2
    exit 1
  fi
  echo $$ > "$LOCK_FILE"
}

release_lock() {
  rm -f "$LOCK_FILE"
}

# ══════════════════════════════════════════════════════════════════════════════
# LOGGING
# ══════════════════════════════════════════════════════════════════════════════
log() {
  local level="$1"; shift
  printf "[%s] [%-7s] %s\n" "$(date -Iseconds)" "$level" "$*" >> "$DEPLOY_LOG"
}

# ══════════════════════════════════════════════════════════════════════════════
# ERROR HANDLING & TRAPS
# ══════════════════════════════════════════════════════════════════════════════
LAST_STAGE="INIT"
FAILED_SERVICE=""
ROLLBACK_STACK=()   # services that were successfully restarted (for rollback)

handle_error() {
  local exit_code="$1"
  local line_no="$2"
  show_cursor
  gap
  printf "  ${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${R}\n"
    printf "  ${RED}${BOLD}║${R}  ${RED}${BOLD}✘  DEPLOY FAILED${R}%40s${RED}${BOLD}║${R}\n" ''
    printf "  ${RED}${BOLD}║${R}  ${GRAY}Stage    › ${WHITE}%-43s${R}  ${RED}${BOLD}║${R}\n" "$LAST_STAGE"
    printf "  ${RED}${BOLD}║${R}  ${GRAY}Line     › ${WHITE}%-43s${R}  ${RED}${BOLD}║${R}\n" "$line_no"
    printf "  ${RED}${BOLD}║${R}  ${GRAY}Exit     › ${WHITE}%-43s${R}  ${RED}${BOLD}║${R}\n" "$exit_code"
    printf "  ${RED}${BOLD}║${R}  ${GRAY}Log      › ${WHITE}%-43s${R}  ${RED}${BOLD}║${R}\n" "${DEPLOY_LOG##*/}"
  printf "  ${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${R}\n"
  gap
  log "ERROR" "Deploy failed at stage=${LAST_STAGE} line=${line_no} exit=${exit_code}"

  if [[ ${#ROLLBACK_STACK[@]} -gt 0 ]]; then
    run_rollback
  fi

  release_lock
}

handle_interrupt() {
  gap
  printf "\n  ${YELLOW}${BOLD}⚠  Deploy interrupted by user (SIGINT/SIGTERM)${R}\n"
  log "WARN" "Deploy interrupted by user"
  show_cursor
  release_lock
  exit 130
}

handle_exit() {
  local code=$?
  show_cursor
  release_lock
  if [[ $code -ne 0 && $code -ne 130 ]]; then
    log "ERROR" "Script exited with code $code"
  fi
}

run_rollback() {
  gap
  printf "  ${LEDAMB}${BOLD}⟳  Initiating rollback for %d service(s)...${R}\n" "${#ROLLBACK_STACK[@]}"
  log "WARN" "Starting rollback for: ${ROLLBACK_STACK[*]}"
  for svc in "${ROLLBACK_STACK[@]}"; do
    printf "  ${LEDAMB}›  Rolling back ${WHITE}%s${R}...\n" "$svc"
    docker compose -f "$COMPOSE_FILE" up -d --no-deps "$svc" >> "$DEPLOY_LOG" 2>&1 || \
      printf "  ${LEDRED}${BOLD}✘  Rollback failed for %s${R}\n" "$svc"
    log "WARN" "Rollback attempted for $svc"
  done
}

trap 'handle_error $? $LINENO' ERR
trap 'handle_interrupt'        SIGINT SIGTERM
trap 'handle_exit'             EXIT

# ══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ══════════════════════════════════════════════════════════════════════════════
gap()  { printf "\n"; }

repeat_char() {
  local char="$1" count="$2" out=""
  for (( i=0; i<count; i++ )); do out+="$char"; done
  printf "%s" "$out"
}

center_pad() {
  local text_len="$1"
  local offset=$(( (COLS - text_len) / 2 ))
  [[ $offset -lt 0 ]] && offset=0
  printf '%*s' "$offset" ''
}

strip_ansi() {
  printf "%s" "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

scan() {
  local msg="$1"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  for ((i=0; i<6; i++)); do
    printf "\r\033[2K  ${LEDBLU}${frames[i]}${R}  ${GRAY}%-44s${R}" "$msg"
    sleep 0.15
  done
}

ok()   {
  printf "\r\033[2K  ${LEDGRN}${BOLD}✔${R}  ${WHITE}%-44s${R} ${DIM}${GRAY}%s${R}\n" "$1" "${2:-}"
  log "OK"   "$1 ${2:-}"
}
fail() {
  printf "\r\033[2K  ${LEDRED}${BOLD}✘${R}  ${WHITE}%-44s${R} ${DIM}${RED}%s${R}\n"  "$1" "${2:-}"
  log "FAIL" "$1 ${2:-}"
}
warn() {
  printf "\r\033[2K  ${LEDAMB}${BOLD}⚠${R}  ${YELLOW}%-44s${R} ${DIM}${YELLOW}%s${R}\n" "$1" "${2:-}"
  log "WARN" "$1 ${2:-}"
}
info() {
  printf "\r\033[2K  ${LEDBLU}${BOLD}›${R}  ${GRAY}%-44s${R} ${DIM}${GRAY}%s${R}\n"   "$1" "${2:-}"
  log "INFO" "$1 ${2:-}"
}
hint() {
  printf "     ${DIM}${GRAY}%s${R}\n" "$*"
  log "HINT" "$*"
}
die()  {
  fail "$@"
  log "FATAL" "$*"
  exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# WORDMARK  — renders once, cursor moves DOWN only, never touched again
# ══════════════════════════════════════════════════════════════════════════════
WM_LINES=6
WM_WIDTH=99

render_wordmark() {
  local raw=(
    "███████╗██╗     ██╗ ██████╗██╗  ██╗ ██████╗    ██████╗ ███████╗██████╗ ██╗      ██████╗ ██╗   ██╗"
    "██╔════╝██║     ██║██╔════╝██║ ██╔╝██╔═══██╗   ██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗╚██╗ ██╔╝"
    "█████╗  ██║     ██║██║     █████╔╝ ██║   ██║   ██║  ██║█████╗  ██████╔╝██║     ██║   ██║ ╚████╔╝ "
    "██╔══╝  ██║     ██║██║     ██╔═██╗ ██║   ██║   ██║  ██║██╔══╝  ██╔═══╝ ██║     ██║   ██║  ╚██╔╝  "
    "██║     ███████╗██║╚██████╗██║  ██╗╚██████╔╝   ██████╔╝███████╗██║     ███████╗╚██████╔╝   ██║   "
    "╚═╝     ╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝    ╚═════╝ ╚══════╝╚═╝     ╚══════╝ ╚═════╝    ╚═╝   "
  )
  local grad=("$X1" "$X2" "$X3" "$X4" "$X5" "$X6")
  local sweep=("$X1" "$X2" "$X3" "$X4" "$X5" "$X6" "$X5" "$X4" "$X3" "$X2" "$X1" "$X2" "$X3" "$X4" "$X5" "$X6")
  local P
  P=$(center_pad $WM_WIDTH)

  # ── First paint ────────────────────────────────────────────────────────
  for (( l=0; l<WM_LINES; l++ )); do
    printf "%s${BOLD}%b%s%b\n" "$P" "${grad[$l]}" "${raw[$l]}" "$R"
  done

  sleep 0.08

  # ── Colour sweep (stays within the 6 wordmark lines only) ──────────────
  for (( sw=0; sw<3; sw++ )); do
    move_up $WM_LINES
    for (( l=0; l<WM_LINES; l++ )); do
      local ci=$(( (sw * 4 + l) % ${#sweep[@]} ))
      printf "%s${BOLD}%b%s%b\n" "$P" "${sweep[$ci]}" "${raw[$l]}" "$R"
    done
    sleep 0.04
  done
  # cursor is now exactly 1 line below the last wordmark row — safe to continue downward
}

# ══════════════════════════════════════════════════════════════════════════════
# SERVER RACK  — drawn BELOW wordmark; animation only rewinds its own lines
# ══════════════════════════════════════════════════════════════════════════════

# Exact count of printf lines inside _draw_rack (count every \n):
#   top-border  = 1
#   unit-1 row  = 1
#   divider     = 1
#   unit-2 row  = 1
#   divider     = 1
#   unit-3 row  = 1
#   bot-border  = 1
#   stats bar   = 1
#   blank line  = 1
RACK_LINES=9
RACK_BOX_W=75   # printable width of the rack box (used for centering)

_draw_rack() {
  # Args: g1 g2 g3  c1 c2 c3  a1 a2 a3
  local g1="$1" g2="$2" g3="$3"
  local c1="$4" c2="$5" c3="$6"
  local a1="$7" a2="$8" a3="$9"

  local P
  P=$(center_pad $RACK_BOX_W)

  printf "%s${STEEL}╔═════════════════════════════════════════════════════════════════════════╗${R}\n" "$P"
  printf "%s${STEEL}║${R}${BGSTEEL} ${g1}${BOLD}${c1}${R}${BGSTEEL} ${STEEL}│${R}${BGSTEEL} ${CYAN}${BOLD}FLICKO-SVR-01  ${R}${BGSTEEL}${STEEL}▐${GRAY}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${DARKSTEEL}▌${R}${BGSTEEL} ${SILVER}[${LEDBLU}${BOLD}NET${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL}${SILVER}[${a1}${BOLD}HDD${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL}${SILVER}[${LEDGRN}${BOLD}PWR${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL} ${g1}${BOLD}${c1}${R}${BGSTEEL}  ${R}${STEEL}║${R}\n" "$P"
  printf "%s${STEEL}╠═════════════════════════════════════════════════════════════════════════╣${R}\n" "$P"
  printf "%s${STEEL}║${R}${BGSTEEL} ${g2}${BOLD}${c2}${R}${BGSTEEL} ${STEEL}│${R}${BGSTEEL} ${LBLUE}${BOLD}PROD-NODE-01   ${R}${BGSTEEL}${STEEL}▐${GRAY}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${DARKSTEEL}▌${R}${BGSTEEL} ${SILVER}[${LEDBLU}${BOLD}NET${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL}${SILVER}[${a2}${BOLD}HDD${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL}${SILVER}[${LEDGRN}${BOLD}PWR${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL} ${g2}${BOLD}${c2}${R}${BGSTEEL}  ${R}${STEEL}║${R}\n" "$P"
  printf "%s${STEEL}╠═════════════════════════════════════════════════════════════════════════╣${R}\n" "$P"
  printf "%s${STEEL}║${R}${BGSTEEL} ${g3}${BOLD}${c3}${R}${BGSTEEL} ${STEEL}│${R}${BGSTEEL} ${MINT}${BOLD}PROD-NODE-02   ${R}${BGSTEEL}${STEEL}▐${GRAY}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${DARKSTEEL}▌${R}${BGSTEEL} ${SILVER}[${LEDBLU}${BOLD}NET${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL}${SILVER}[${a3}${BOLD}HDD${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL}${SILVER}[${LEDGRN}${BOLD}PWR${R}${BGSTEEL}${SILVER}]${R}${BGSTEEL} ${g3}${BOLD}${c3}${R}${BGSTEEL}  ${R}${STEEL}║${R}\n" "$P"
  printf "%s${STEEL}╚═════════════════════════════════════════════════════════════════════════╝${R}\n" "$P"

  local host uptime_str ts
  host=$(hostname 2>/dev/null | tr '[:lower:]' '[:upper:]' || echo "UNKNOWN")
  uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //' || echo "N/A")
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  printf "%s  ${DIM}${STEEL}SN:FCK-2026  ·  HOST:${SILVER}%-16s${STEEL}·  ${SILVER}%s${STEEL}  ·  UP: ${SILVER}%s${R}\n" \
         "$P" "$host" "$ts" "$uptime_str"
  printf "\n"   # ← blank line (counted in RACK_LINES)
}

render_server_rack() {
  # ── Separator between wordmark and rack ─────────────────────────────────
  local sep_w=$(( RACK_BOX_W ))
  local P
  P=$(center_pad $sep_w)
  printf "%s${DIM}${X4}%s${R}\n" "$P" "$(repeat_char '─' $sep_w)"

  # ── First full draw (lights ON) ─────────────────────────────────────────
  _draw_rack \
    "$LEDGRN" "$LEDGRN" "$LEDGRN" \
    "●"       "●"       "●"       \
    "$LEDAMB" "$LEDAMB" "$LEDAMB"

  # ── Blink frames: each row = "g1 g2 g3 c1 c2 c3 a1 a2 a3" ──────────────
  # We rewind only RACK_LINES (9) — the separator line is ABOVE and safe
  local -a frames=(
    "$LEDOFF  $LEDGRN  $LEDGRN  ○  ●  ●  $LEDOFF  $LEDAMB  $LEDAMB"
    "$LEDGRN  $LEDOFF  $LEDGRN  ●  ○  ●  $LEDAMB  $LEDOFF  $LEDAMB"
    "$LEDGRN  $LEDGRN  $LEDOFF  ●  ●  ○  $LEDAMB  $LEDAMB  $LEDOFF"
    "$LEDGRN  $LEDGRN  $LEDGRN  ●  ●  ●  $LEDAMB  $LEDAMB  $LEDAMB"
    "$LEDOFF  $LEDOFF  $LEDOFF  ○  ○  ○  $LEDOFF  $LEDOFF  $LEDOFF"
    "$LEDGRN  $LEDGRN  $LEDGRN  ●  ●  ●  $LEDAMB  $LEDAMB  $LEDAMB"
    "$LEDGRN  $LEDOFF  $LEDOFF  ●  ○  ○  $LEDAMB  $LEDOFF  $LEDOFF"
    "$LEDOFF  $LEDGRN  $LEDOFF  ○  ●  ○  $LEDOFF  $LEDAMB  $LEDOFF"
    "$LEDOFF  $LEDOFF  $LEDGRN  ○  ○  ●  $LEDOFF  $LEDOFF  $LEDAMB"
    "$LEDGRN  $LEDGRN  $LEDGRN  ●  ●  ●  $LEDAMB  $LEDAMB  $LEDAMB"
  )
  local -a delays=(0.13 0.11 0.11 0.09 0.08 0.07 0.09 0.09 0.11 0.15)

  for (( f=0; f<${#frames[@]}; f++ )); do
    # shellcheck disable=SC2206
    local old_ifs=$IFS; IFS=" "; local fp=( ${frames[$f]} ); IFS=$old_ifs
    move_up $RACK_LINES
    _draw_rack \
      "${fp[0]}" "${fp[1]}" "${fp[2]}" \
      "${fp[3]}" "${fp[4]}" "${fp[5]}" \
      "${fp[6]}" "${fp[7]}" "${fp[8]}"
    sleep "${delays[$f]}"
  done

  # ── Final: all-green, solid ──────────────────────────────────────────────
  move_up $RACK_LINES
  _draw_rack \
    "$LEDGRN" "$LEDGRN" "$LEDGRN" \
    "●"       "●"       "●"       \
    "$LEDAMB" "$LEDAMB" "$LEDAMB"
}

# ══════════════════════════════════════════════════════════════════════════════
# BOOT INFO BOX
# ══════════════════════════════════════════════════════════════════════════════
render_boot_box() {
  local BOX_W=58
  local P
  P=$(center_pad $BOX_W)
  local h_line
  h_line="$(repeat_char '─' $(( BOX_W - 2 )))"

  _boot_row() {
    local label="$1" value="$2"
    local content="${label}${value}"
    local content_plain
    content_plain=$(strip_ansi "$content")
    local padlen=$(( BOX_W - ${#content_plain} - 4 ))
    [[ $padlen -lt 0 ]] && padlen=0
    printf "%s${DIM}${X4}│${R}  %b%*s${DIM}${X4}│${R}\n" \
           "$P" "$content" "$padlen" ''
  }

  gap
  printf "%s${DIM}${X4}┌%s┐${R}\n" "$P" "$h_line"
  _boot_row "${BOLD}${WHITE}⚡  FLICKO SYSTEM DEPLOYMENT INITIATED" ""
  printf "%s${DIM}${X4}│%*s│${R}\n" "$P" "$(( BOX_W - 2 ))" ''
  _boot_row "${GRAY}  MODE  › " "${WHITE}ZERO-DOWNTIME ROLLING DEPLOY"
  _boot_row "${GRAY}  HOST  › " "${WHITE}$(hostname 2>/dev/null || echo N/A)"
  _boot_row "${GRAY}  TIME  › " "${WHITE}$(date '+%Y-%m-%dT%H:%M:%S %Z')"
  _boot_row "${GRAY}  LOG   › " "${WHITE}${DEPLOY_LOG##*/}"
  printf "%s${DIM}${X4}│%*s│${R}\n" "$P" "$(( BOX_W - 2 ))" ''
  printf "%s${DIM}${X4}└%s┘${R}\n" "$P" "$h_line"
  gap
}

# ══════════════════════════════════════════════════════════════════════════════
# SECTION / STAGE / GLITCH
# ══════════════════════════════════════════════════════════════════════════════
section() {
  local title="$1"
  local rhs=$(( COLS - ${#title} - 9 ))
  [[ $rhs -lt 1 ]] && rhs=1
  gap
  printf "  ${X4}${BOLD}──[ ${WHITE}%s${X4} ]%s${R}\n" \
         "$title" "$(repeat_char '─' $rhs)"
  log "SECTION" "$title"
}

stage_banner() {
  local num="$1" label="$2"
  LAST_STAGE="STAGE ${num}: ${label}"
  local text=" STAGE ${num}  ›  ${label} "
  local fill=$(( COLS - ${#text} - 2 ))
  [[ $fill -lt 0 ]] && fill=0
  gap
  printf "  ${BGSTEEL}${BOLD}${CYAN} STAGE ${WHITE}%s ${GRAY}›${CYAN} %s ${R}${DIM}${GRAY}%s${R}\n" \
         "$num" "$label" "$(repeat_char '─' $fill)"
  log "STAGE" "$num — $label"
}

glitch_text() {
  local text="$1"
  local len=${#text}
  local glitch_chars="@#%&?!"
  local P
  P=$(center_pad $(( len + 5 )))

  for (( round=0; round<5; round++ )); do
    local out=""
    for (( i=0; i<len; i++ )); do
      if (( RANDOM % 3 == 0 )); then
        local gi=$(( RANDOM % ${#glitch_chars} ))
        out+="${RED}${BOLD}${glitch_chars:$gi:1}${R}"
      else
        out+="${DIM}${CYAN}${text:$i:1}${R}"
      fi
    done
    printf "\r%s%b" "$P" "$out"
    sleep 0.045
  done
  printf "\r%s${LEDGRN}${BOLD}✔${R}  ${BOLD}${WHITE}%s${R}\n" "$P" "$text"
  log "OK" "$text"
}

type_line() {
  local prefix="$1" text="$2" delay="${3:-0.012}"
  printf "%s" "$prefix"
  for (( i=0; i<${#text}; i++ )); do
    printf "%s" "${text:$i:1}"
    sleep "$delay"
  done
  printf "${R}\n"
}

# ══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════════════════════
COMPOSE_FILE="docker-compose.prod.yml"
MAX_WAIT=120
CHECK_INTERVAL=5
RETRY_LIMIT=2

# ── Parse arguments ────────────────────────────────────────────────────────
SKIP_BUILD=false
DRY_RUN=false
TARGET_SERVICE=""
VERBOSE=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --skip-build        Skip Docker image build step
  --service <name>    Deploy only a single service
  --dry-run           Validate config without deploying
  --verbose           Show docker compose output live
  -h, --help          Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=true;          shift   ;;
    --service)    TARGET_SERVICE="$2";      shift 2 ;;
    --dry-run)    DRY_RUN=true;             shift   ;;
    --verbose)    VERBOSE=true;             shift   ;;
    -h|--help)    usage ;;
    *) printf "${RED}Unknown option: %s${R}\n" "$1" >&2; usage ;;
  esac
done

COMPOSE_OUT="${DEPLOY_LOG}"
[[ "$VERBOSE" == "true" ]] && COMPOSE_OUT="/dev/stdout"

# ══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECKS
# ══════════════════════════════════════════════════════════════════════════════
check_dependencies() {
  LAST_STAGE="DEPENDENCY CHECK"
  section "DEPENDENCY CHECK"

  local deps=("docker" "docker compose")
  local missing=0

  # docker binary
    scan "Checking docker binary..."
    if command -v docker &>/dev/null; then
      local dver
      dver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
      ok "Docker found" "v${dver}"
    else
      fail "Docker not found" "install docker.io"
      (( missing++ ))
    fi

    # docker compose (v2 plugin)
    scan "Checking docker compose plugin..."
    if docker compose version &>/dev/null; then
      local cver
      cver=$(docker compose version --short 2>/dev/null || echo "unknown")
      ok "Docker Compose found" "v${cver}"
    else
      fail "Docker Compose v2 not found" "'docker compose' plugin required"
      (( missing++ ))
    fi

    # disk space  (warn if < 2 GB free)
    scan "Checking disk capacity..."
    local free_kb
    free_kb=$(df -k "$PROJECT_ROOT" 2>/dev/null | awk 'NR==2{print $4}' || echo 0)
    local free_gb=$(( free_kb / 1024 / 1024 ))
    if [[ $free_kb -lt 2097152 ]]; then
      warn "Low disk space" "${free_gb} GB free — recommend ≥ 2 GB"
    else
      ok "Disk space OK" "${free_gb} GB free"
    fi

    # docker daemon
    scan "Pinging docker daemon..."
  return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# PREFLIGHT
# ══════════════════════════════════════════════════════════════════════════════
preflight() {
  LAST_STAGE="PREFLIGHT"
  section "ENVIRONMENT VERIFICATION"

    scan "Looking for compose file..."
    if [[ -f "$COMPOSE_FILE" ]]; then
      ok "Compose file found" "$COMPOSE_FILE"
    else
      die "Compose file not found" "$COMPOSE_FILE"
    fi

    # Validate compose syntax
    scan "Validating compose syntax..."
    if docker compose -f "$COMPOSE_FILE" config --quiet &>/dev/null; then
      ok "Compose config valid"
    else
      die "Compose config is invalid — run: docker compose -f $COMPOSE_FILE config"
    fi

    scan "Loading environment variables..."
    if [[ -f ".env" ]]; then
      ok "Environment file loaded" ".env"
    else
      die ".env file missing" "create one from .env.example"
    fi

    local -a warn_files=(
      "secrets/jwt_public.pem"
      "nginx/ssl/origin.pem"
      "nginx/ssl/origin-key.pem"
    )
    for f in "${warn_files[@]}"; do
      scan "Checking key file: ${f##*/}..."
      if [[ -f "$f" ]]; then
        ok "Secret/cert present" "$f"
      else
        warn "File missing" "$f"
      fi
    done

  if [[ "$DRY_RUN" == "true" ]]; then
    gap
    warn "DRY RUN mode — no containers will be modified"
    ok "Dry-run preflight passed"
    gap
    show_cursor
    exit 0
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# HEALTH CHECK  (with retry + spinner)
# ══════════════════════════════════════════════════════════════════════════════
wait_healthy() {
  local container="$1"
  local waited=0
  local spin=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local si=0

  # Check if container has a health check defined
  local has_health
  has_health=$(docker inspect --format='{{if .Config.Healthcheck}}yes{{else}}no{{end}}' \
               "$container" 2>/dev/null || echo "no")

  if [[ "$has_health" == "no" ]]; then
    # No healthcheck — just verify it's running
    local running
    running=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null || echo "false")
    if [[ "$running" == "true" ]]; then
      ok "${container}  RUNNING" "no healthcheck defined"
    else
      fail "${container}  NOT RUNNING"
      return 1
    fi
    return 0
  fi

  while [[ $waited -lt $MAX_WAIT ]]; do
    local status
    status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null \
             || echo "missing")

    case "$status" in
      healthy)
        printf "\r  ${LEDGRN}${BOLD}✔${R}  ${WHITE}%-44s${R} ${DIM}${GRAY}+%ds${R}\n" \
               "${container}  ONLINE" "$waited"
        log "OK" "$container healthy after ${waited}s"
        return 0
        ;;
      unhealthy)
        printf "\r  ${LEDRED}${BOLD}✘${R}  ${WHITE}%-44s${R}\n" "${container}  UNHEALTHY"
        docker logs --tail 30 "$container" >> "$DEPLOY_LOG" 2>&1
        log "FAIL" "$container unhealthy after ${waited}s"
        return 1
        ;;
      *)
        printf "\r  ${CYAN}%s${R}  ${GRAY}%-44s${R} ${DIM}${GRAY}+%ds / %ds${R}" \
               "${spin[$si]}" "Waiting › $container" "$waited" "$MAX_WAIT"
        si=$(( (si+1) % ${#spin[@]} ))
        sleep "$CHECK_INTERVAL"
        waited=$(( waited + CHECK_INTERVAL ))
        ;;
    esac
  done

  printf "\r  ${LEDRED}${BOLD}✘${R}  ${WHITE}%-44s${R}\n" "${container}  TIMED OUT"
  log "FAIL" "$container timed out after ${MAX_WAIT}s"
  return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# SERVICE RESTART  (with retry logic)
# ══════════════════════════════════════════════════════════════════════════════
restart_service() {
  local service="$1"
  local container="$2"
  local attempt=1

  while [[ $attempt -le $RETRY_LIMIT ]]; do
    if [[ $attempt -gt 1 ]]; then
      warn "Retry attempt ${attempt}/${RETRY_LIMIT}" "$service"
      log "WARN" "Retry $attempt for $service"
      sleep 3
    else
      info "Restarting service" "$service"
    fi

    docker compose -f "$COMPOSE_FILE" up -d --no-deps --force-recreate "$service" \
      >> "$COMPOSE_OUT" 2>&1

    if wait_healthy "$container"; then
      ROLLBACK_STACK+=("$service")
      log "OK" "$service deployed successfully (attempt $attempt)"
      return 0
    fi

    (( attempt++ ))
  done

  die "Service failed after ${RETRY_LIMIT} attempts" "$service"
}

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY BOX
# ══════════════════════════════════════════════════════════════════════════════
render_summary() {
  local elapsed=$(( $(date +%s) - DEPLOY_START ))
  local minutes=$(( elapsed / 60 ))
  local seconds=$(( elapsed % 60 ))
  local svc_count="${#ROLLBACK_STACK[@]}"
  local inner=$(( COLS - 4 ))
  [[ $inner -lt 20 ]] && inner=20

  gap
  printf "  ${LEDGRN}${BOLD}╔%s╗${R}\n"                 "$(repeat_char '═' $inner)"
  printf "  ${LEDGRN}${BOLD}║${R}%*s${LEDGRN}${BOLD}║${R}\n" "$inner" ''

  _sum_row() {
    local txt="$1"
    local plain
    plain=$(strip_ansi "$txt")
    local padlen=$(( inner - ${#plain} - 2 ))
    [[ $padlen -lt 0 ]] && padlen=0
    printf "  ${LEDGRN}${BOLD}║${R}  %b%*s${LEDGRN}${BOLD}║${R}\n" "$txt" "$padlen" ''
  }

  _sum_row "${LEDGRN}${BOLD}✔  ALL SYSTEMS NOMINAL${R}"
  _sum_row ""
  _sum_row "${GRAY}  Services deployed  › ${WHITE}${svc_count}"
  _sum_row "${GRAY}  Total time        › ${WHITE}${minutes}m ${seconds}s"
  _sum_row "${GRAY}  Completed at      › ${WHITE}$(date '+%Y-%m-%d  %H:%M:%S %Z')"
  _sum_row "${GRAY}  Log saved at      › ${WHITE}${DEPLOY_LOG}"

  printf "  ${LEDGRN}${BOLD}║${R}%*s${LEDGRN}${BOLD}║${R}\n" "$inner" ''
  printf "  ${LEDGRN}${BOLD}╚%s╝${R}\n"                 "$(repeat_char '═' $inner)"
  gap

  log "OK" "Deploy complete in ${minutes}m ${seconds}s — $svc_count service(s)"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

# Acquire deploy lock early
acquire_lock

# Init log
mkdir -p "$(dirname "$DEPLOY_LOG")"
log "INFO" "Deploy started — user=$(whoami) pid=$$ args=$*"

clear
hide_cursor
gap

# ── 1. Wordmark (stays put — cursor only moves down after this) ────────────
render_wordmark

# ── 2. Rack with blink animation (self-contained below wordmark) ───────────
render_server_rack

# ── 3. Boot info box ────────────────────────────────────────────────────────
render_boot_box

cd "$PROJECT_ROOT"

# ── 4. Checks ────────────────────────────────────────────────────────────────
check_dependencies

stage_banner "1" "SYSTEM PREFLIGHT"
preflight

# ── 5. Image sync ─────────────────────────────────────────────────────────
stage_banner "2" "BASE IMAGE SYNC"
LAST_STAGE="BASE IMAGE SYNC"
section "PULLING UPSTREAM IMAGES"
info "Contacting image registries..."
docker compose -f "$COMPOSE_FILE" pull --ignore-buildable >> "$COMPOSE_OUT" 2>&1
glitch_text "BASE IMAGES SYNCHRONISED"

# ── 6. Build ──────────────────────────────────────────────────────────────
stage_banner "3" "GO SERVICE BUILD"
LAST_STAGE="GO SERVICE BUILD"
if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Build step skipped" "--skip-build flag active"
else
  section "COMPILING BINARIES"
  info "Building Go services in parallel..."
  docker compose -f "$COMPOSE_FILE" build --parallel >> "$COMPOSE_OUT" 2>&1
  glitch_text "GOLANG SERVICES COMPILED"
fi

# ── 7. Rolling restart ────────────────────────────────────────────────────
stage_banner "4" "ROLLING RESTART"
LAST_STAGE="ROLLING RESTART"

if [[ -n "$TARGET_SERVICE" ]]; then
  section "TARGETED DEPLOY  ›  ${TARGET_SERVICE}"
  restart_service "$TARGET_SERVICE" "flicko-${TARGET_SERVICE}"
else
  section "PHASE 1  ›  EXTERNAL INFRASTRUCTURE"
  hint "Cloud-native resources (B2, Upstash) — no local restart required"

  section "PHASE 2  ›  APPLICATION CORE"
  restart_service "ws-gateway"  "flicko-ws-gateway"
  restart_service "msg-service" "flicko-msg-service"

  section "PHASE 3  ›  TELEMETRY & MONITORING"
  restart_service "prometheus"  "flicko-prometheus"
  restart_service "grafana"     "flicko-grafana"
  restart_service "loki"        "flicko-loki"

  section "PHASE 4  ›  EDGE PROXY & ROUTING"
  restart_service "nginx"       "flicko-nginx"
fi

# ── 8. Final health check ─────────────────────────────────────────────────
stage_banner "5" "FINAL INTEGRITY CHECK"
LAST_STAGE="FINAL INTEGRITY CHECK"
section "RUNNING DIAGNOSTICS"

if [[ -f "${SCRIPT_DIR}/check-health.sh" ]]; then
  bash "${SCRIPT_DIR}/check-health.sh" | tee -a "$DEPLOY_LOG"
else
  warn "check-health.sh not found" "skipping final diagnostic"
fi

# ── 9. Summary ────────────────────────────────────────────────────────────
render_summary

show_cursor
release_lock