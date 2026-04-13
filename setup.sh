#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────────────────
#  Flicko — Setup Wizard 
# ─────────────────────────────────────────────────────────────────────────────

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
hint() { printf "      ${DIM}${GRAY}%s${R}\n" "$*"; }

# ── Section header ────────────────────────────────────────────────────────────
section() {
  local title="$1"
  local rhs=$(( COLS - ${#title} - 9 ))
  [ "$rhs" -lt 1 ] && rhs=1
  gap
  local line="  ${CYAN}$(repeat_char '─' 2)[ ${BOLD}${WHITE}${title}${R}${CYAN} ]$(repeat_char '─' $rhs)${R}"
  printf "%b\n" "$line"
}

# ── Numbered step ─────────────────────────────────────────────────────────────
step_label() {
  local n="$1" msg="$2"
  printf "  ${GRAY}[${R}${CYAN}${BOLD}%02d${R}${GRAY}]${R}  %s\n" "$n" "$msg"
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

# ── Matrix rain (FIXED — echo -e, pure ASCII art chars only) ─────────────────
matrix_burst() {
  local width=$(( COLS - 4 ))
  local cols_count=6
  local col_width=$(( width / cols_count ))
  local all_cols=()

  # Each column gets a random starting offset
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
        if   (( dist == 0 ));        then line+="${BOLD}${WHITE}"
        elif (( dist > 0 && dist < 3 )); then line+="${GREEN}"
        elif (( dist >= 3 ));        then line+="${GRAY}${DIM}"
        else                              line+="${GRAY}${DIM}"
        fi
        # Only safe printable ASCII — no block chars, no backslash
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
    # Advance some columns
    for (( c=0; c<cols_count; c++ )); do
      if (( RANDOM % 2 == 0 )); then
        all_cols[$c]=$(( all_cols[$c] + 1 ))
      fi
    done
  done

  tput cnorm 2>/dev/null
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

# ─────────────────────────────────────────────────────────────────────────────
#  BOOT ANIMATION  (runs before everything else)
# ─────────────────────────────────────────────────────────────────────────────
boot_sequence() {
  clear
  tput civis 2>/dev/null

  local w=$(( COLS - 4 ))

  # ── Phase 1: scan lines ───────────────────────────────────────────────────
  for (( i=0; i<3; i++ )); do
    printf "  ${GREEN}${DIM}"
    local rn=$(( RANDOM % 62 ))
    local line=""
    for (( j=0; j<w; j++ )); do
      rn=$(( RANDOM % 62 ))
      if   (( rn < 10 )); then line+="$rn"
      elif (( rn < 36 )); then
        local code=$(( rn - 10 + 65 ))
        line+="$(printf "\\$(printf '%03o' $code)")"
      else
        local code=$(( rn - 36 + 97 ))
        line+="$(printf "\\$(printf '%03o' $code)")"
      fi
    done
    printf "%s${R}\n" "$line"
    sleep 0.04
  done
  gap

  # ── Phase 2: BIOS-style boot messages ────────────────────────────────────
  local bios_lines=(
    "${GRAY}FLICKO-BIOS v2.1.0  │  64MB VRAM  │  CPU: SETUP-CORE x4${R}"
    "${GRAY}Detecting terminal geometry...  ${GREEN}OK${R}"
    "${GRAY}Mounting colour palette...      ${GREEN}OK${R}"
    "${GRAY}Loading animation engine...     ${GREEN}OK${R}"
    "${GRAY}Initialising prerequisite map...${GREEN}OK${R}"
  )
  for line in "${bios_lines[@]}"; do
    printf "  "
    printf "%b\n" "$line"
    sleep 0.12
  done
  gap

  # ── Phase 3: segmented progress bar with phase labels ────────────────────
  local phases=(
    "KERNEL   "
    "MODULES  "
    "SERVICES "
    "DISPLAY  "
    "READY    "
  )
  local phase_colours=(
    "$M"  "$P"  "$B"  "$CB"  "$GREEN"
  )
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
      local filled=$s
      local empty=$(( bar_w - s ))
      local pct=$(( s * 100 / bar_w ))

      # Build gradient fill
      local bar=""
      for (( b=0; b<filled; b++ )); do
        local seg=$(( b * total_phases / bar_w ))
        bar+="${phase_colours[$seg]}|${R}"
      done

      printf "\r  ${col}${BOLD}[%s]${R}  [%b${GRAY}$(repeat_char '.' $empty)${R}]  ${BOLD}${WHITE}%3d%%${R}" \
        "$label" "$bar" "$pct"
      sleep 0.012
    done
  done
  printf "\n"
  gap

  # ── Phase 4: flicker flash then clear ────────────────────────────────────
  for (( f=0; f<2; f++ )); do
    printf "  ${GREEN}${BOLD}[ FLICKO SETUP — SYSTEM GO ]${R}\n"
    sleep 0.07
    tput cuu1 2>/dev/null
    printf "%${COLS}s\r" ""
    sleep 0.05
  done
  printf "  ${GREEN}${BOLD}[ FLICKO SETUP — SYSTEM GO ]${R}\n"
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
#  MAIN SCREEN — matrix burst header
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
WORD_LINES=(
  "  ${M}███████${MP}╗${R}  ${P}██${PB}╗${R}      ${B}██${BB}╗${R}   ${CB}██████${C}╗${R}  ${M}██${MP}╗${R}  ${P}██${PB}╗${R}   ${B}██████${BB}╗${R}"
  "  ${M}██${MP}╔════╝${R}  ${P}██${PB}║${R}      ${B}██${BB}║${R}  ${CB}██${C}╔════╝${R}  ${M}██${MP}║${R} ${P}██${PB}╔╝${R}  ${B}██${BB}╔═══██╗${R}"
  "  ${M}█████${MP}╗${R}    ${P}██${PB}║${R}      ${B}██${BB}║${R}  ${CB}██${C}║${R}       ${M}█████${MP}╔╝${R}   ${B}██${BB}║   ██║${R}"
  "  ${M}██${MP}╔══╝${R}    ${P}██${PB}║${R}      ${B}██${BB}║${R}  ${CB}██${C}║${R}       ${M}██${MP}╔═${P}██${PB}╗${R}   ${B}██${BB}║   ██║${R}"
  "  ${M}██${MP}║${R}       ${P}███████${PB}╗${R} ${B}██${BB}║${R}  ${CB}╚██████${C}╗${R}  ${M}██${MP}║${R}  ${P}╚█${PB}█╗${R} ${B}╚██████${BB}╔╝${R}"
  "  ${GRAY}╚═╝       ╚══════╝ ╚═╝   ╚═════╝  ╚═╝   ╚══╝  ╚═════╝${R}"
)

for line in "${WORD_LINES[@]}"; do
  printf "${BOLD}%b\n" "$line"
done

gap

# ── Sub-title ─────────────────────────────────────────────────────────────────
SUBTITLE="[ REAL-TIME  *  COMMUNITY  *  PLATFORM  *  v1.0.0 ]"
SUB_PAD=$(( (COLS - ${#SUBTITLE}) / 2 ))
[ "$SUB_PAD" -lt 0 ] && SUB_PAD=0
printf "%${SUB_PAD}s${GRAY}%s${R}\n" "" "$SUBTITLE"

gap

# ── Timestamp badge ───────────────────────────────────────────────────────────
BADGE="  ** flicko-setup  |  $(date '+%Y-%m-%d %H:%M:%S')  "
BADGE_PAD=$(( (COLS - ${#BADGE}) / 2 ))
[ "$BADGE_PAD" -lt 0 ] && BADGE_PAD=0
printf "%${BADGE_PAD}s${BG_DARK}${CYAN}${BOLD}%s${R}\n" "" "$BADGE"

gap
printf "  ${CYAN}$(repeat_char '=' $(( COLS - 4 )))${R}\n"

tput cnorm 2>/dev/null

# ─────────────────────────────────────────────────────────────────────────────
#  PROJECT INFO
# ─────────────────────────────────────────────────────────────────────────────
section "PROJECT"
gap

printf "  ${GRAY}|${R}  ${BOLD}${WHITE}%-*s${R}  ${GRAY}|${R}\n" \
  "$(( COLS - 10 ))" "Flicko — Discord-inspired real-time community platform"

gap

TABLE_W=$(( COLS - 4 ))
printf "  ${GRAY}+$(repeat_char '-' $(( TABLE_W - 2 )))+${R}\n"
printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-10s${R}  ${GRAY}|${R}  ${WHITE}%-*s${R}  ${GRAY}|${R}\n" \
  "FRONTEND"  "$(( TABLE_W - 19 ))" "React Native  *  Expo  *  TypeScript"
printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-10s${R}  ${GRAY}|${R}  ${WHITE}%-*s${R}  ${GRAY}|${R}\n" \
  "BACKEND"   "$(( TABLE_W - 19 ))" "Go  *  ws-gateway  *  msg-service"
printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-10s${R}  ${GRAY}|${R}  ${WHITE}%-*s${R}  ${GRAY}|${R}\n" \
  "INFRA"     "$(( TABLE_W - 19 ))" "Supabase  *  Redis  *  Docker  *  LiveKit"
printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-10s${R}  ${GRAY}|${R}  ${WHITE}%-*s${R}  ${GRAY}|${R}\n" \
  "OBS"       "$(( TABLE_W - 19 ))" "Prometheus  *  Grafana  *  pprof"
printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-10s${R}  ${GRAY}|${R}  ${WHITE}%-*s${R}  ${GRAY}|${R}\n" \
  "LICENSE"   "$(( TABLE_W - 19 ))" "Apache 2.0"
printf "  ${GRAY}+$(repeat_char '-' $(( TABLE_W - 2 )))+${R}\n"

gap
info "github.com/Santosh-Prasad-Verma/Flicko"

# ─────────────────────────────────────────────────────────────────────────────
#  PREREQUISITE CHECKS
# ─────────────────────────────────────────────────────────────────────────────
section "PREREQUISITE CHECKS"
gap

dbg "Scanning PATH for required tools..."
gap

PASS=0
FAIL=0
TOTAL_TOOLS=5

check_tool() {
  local name="$1" cmd="$2"
  start_spinner "Checking ${name}..."
  sleep 0.3

  if command -v "$name" &>/dev/null; then
    local ver
    ver=$(eval "$cmd" 2>/dev/null | head -1 | tr -d '\n')
    stop_spinner
    PASS=$(( PASS + 1 ))
    ok "${BOLD}${name}${R}  ${GRAY}-> ${ver}${R}"
  else
    stop_spinner
    FAIL=$(( FAIL + 1 ))
    fail "${BOLD}${name}${R}  ${GRAY}-> not found in PATH${R}"
  fi
  progress_bar "$(( PASS + FAIL ))" "$TOTAL_TOOLS"
  gap
}

check_tool "node"    "node --version"
check_tool "npm"     "npm --version"
check_tool "go"      "go version"
check_tool "docker"  "docker --version"
check_tool "git"     "git --version"

# Result banner
printf "  ${GRAY}$(repeat_char '-' $(( COLS - 4 )))${R}\n"
gap

if [ "$FAIL" -eq 0 ]; then
  glitch_text "All ${PASS}/${TOTAL_TOOLS} prerequisites satisfied"
  gap
  printf "  ${BG_GREEN}${BOLD}${WHITE}  [OK]  System is ready — proceed to setup  ${R}\n"
else
  printf "  ${BG_RED}${BOLD}${WHITE}  [!!]  ${FAIL} missing tool(s) — install before continuing  ${R}\n"
  gap
  warn "Install missing tools then re-run this script"
  hint "node/npm  ->  https://nodejs.org"
  hint "go        ->  https://go.dev/dl"
  hint "docker    ->  https://docs.docker.com/get-docker"
  hint "git       ->  https://git-scm.com"
fi

gap

# ─────────────────────────────────────────────────────────────────────────────
#  GETTING STARTED
# ─────────────────────────────────────────────────────────────────────────────
section "GETTING STARTED"
gap

step_label 1 "${BOLD}Infrastructure${R}  ${GRAY}— local metrics and Redis stack${R}"
gap
printf "  ${GRAY}|${R}\n"
printf "  ${GRAY}|${R}  ${GRAY}run:${R}\n"
printf "  ${GRAY}|${R}  ${BOLD}${GREEN}>>${R}  "
type_text "./scripts/dev-start.sh" 0.022
printf "  ${GRAY}|${R}\n"
info "Starts Redis + Prometheus + Grafana via Docker Compose"
gap

step_label 2 "${BOLD}Backend Services${R}  ${GRAY}— Go microservices (separate terminals)${R}"
gap
printf "  ${GRAY}|${R}\n"
printf "  ${GRAY}|${R}  ${GRAY}terminal 1:${R}\n"
printf "  ${GRAY}|${R}  ${BOLD}${GREEN}>>${R}  "
type_text "cd services && go run ./msg-service/cmd/server" 0.018
printf "  ${GRAY}|${R}\n"
printf "  ${GRAY}|${R}  ${GRAY}terminal 2:${R}\n"
printf "  ${GRAY}|${R}  ${BOLD}${GREEN}>>${R}  "
type_text "cd services && go run ./ws-gateway/cmd/gateway" 0.018
printf "  ${GRAY}|${R}\n"
info "msg-service  ->  http://localhost:8085"
info "ws-gateway   ->  ws://localhost:8080"
gap

step_label 3 "${BOLD}Mobile App${R}  ${GRAY}— Expo React Native client${R}"
gap
printf "  ${GRAY}|${R}\n"
printf "  ${GRAY}|${R}  ${GRAY}run:${R}\n"
printf "  ${GRAY}|${R}  ${BOLD}${GREEN}>>${R}  "
type_text "cd mobile && npm install && npx expo start" 0.018
printf "  ${GRAY}|${R}\n"
info "Scan the QR code in Expo Go  *  or press 'a' for Android emulator"
gap

# ─────────────────────────────────────────────────────────────────────────────
#  QUICK REFERENCE
# ─────────────────────────────────────────────────────────────────────────────
section "QUICK REFERENCE"
gap

REF_W=$(( COLS - 4 ))
printf "  ${GRAY}+$(repeat_char '-' $(( REF_W - 2 )))+${R}\n"
printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-22s${R}  ${GRAY}|${R}  ${WHITE}%-*s${R}  ${GRAY}|${R}\n" \
  "FILE / RESOURCE" "$(( REF_W - 31 ))" "PURPOSE"
printf "  ${GRAY}+$(repeat_char '-' $(( REF_W - 2 )))+${R}\n"
printf "  ${GRAY}|${R}  ${YELLOW}%-22s${R}  ${GRAY}|${R}  ${GRAY}%-*s${R}  ${GRAY}|${R}\n" \
  ".env.example"            "$(( REF_W - 31 ))" "copy to .env and fill in secrets"
printf "  ${GRAY}|${R}  ${YELLOW}%-22s${R}  ${GRAY}|${R}  ${GRAY}%-*s${R}  ${GRAY}|${R}\n" \
  "README.md"               "$(( REF_W - 31 ))" "full project documentation"
printf "  ${GRAY}|${R}  ${YELLOW}%-22s${R}  ${GRAY}|${R}  ${GRAY}%-*s${R}  ${GRAY}|${R}\n" \
  "scripts/dev-start.sh"    "$(( REF_W - 31 ))" "spin up local infra stack"
printf "  ${GRAY}|${R}  ${YELLOW}%-22s${R}  ${GRAY}|${R}  ${GRAY}%-*s${R}  ${GRAY}|${R}\n" \
  "scripts/run-backend.sh"  "$(( REF_W - 31 ))" "launch all Go services"
printf "  ${GRAY}|${R}  ${YELLOW}%-22s${R}  ${GRAY}|${R}  ${GRAY}%-*s${R}  ${GRAY}|${R}\n" \
  "scripts/expo-usb.sh"     "$(( REF_W - 31 ))" "USB ADB metro launcher"
printf "  ${GRAY}+$(repeat_char '-' $(( REF_W - 2 )))+${R}\n"

gap

# ─────────────────────────────────────────────────────────────────────────────
#  FOOTER
# ─────────────────────────────────────────────────────────────────────────────
gap
printf "  ${CYAN}$(repeat_char '=' $(( COLS - 4 )))${R}\n"
gap

REPO="https://github.com/Santosh-Prasad-Verma/Flicko"
REPO_PAD=$(( (COLS - ${#REPO} - 5) / 2 ))
[ "$REPO_PAD" -lt 0 ] && REPO_PAD=0
printf "%${REPO_PAD}s${GRAY}[*]  ${CYAN}${BOLD}%s${R}\n" "" "$REPO"

gap

CREDIT="Made with ♥ by the Flicko team"
CREDIT_PAD=$(( (COLS - ${#CREDIT}) / 2 ))
[ "$CREDIT_PAD" -lt 0 ] && CREDIT_PAD=0
printf "%${CREDIT_PAD}s${GRAY}%s${R}\n" "" "$CREDIT"

gap
printf "  ${CYAN}$(repeat_char '=' $(( COLS - 4 )))${R}\n"
gap