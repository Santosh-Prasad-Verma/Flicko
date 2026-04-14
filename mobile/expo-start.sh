#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────────────────
#  expo-usb.sh — Hacker Edition USB Launcher
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ── Colours ───────────────────────────────────────────────────────────────────
R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
BLINK=$'\033[5m'

WHITE=$'\033[97m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
RED=$'\033[91m'
BLUE=$'\033[94m'
MAGENTA=$'\033[95m'
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

BG_PURPLE=$'\033[48;5;57m'
BG_DARK=$'\033[48;5;234m'
BG_GREEN=$'\033[48;5;22m'
BG_RED=$'\033[48;5;52m'
BG_BLACK=$'\033[40m'
BG_CYAN=$'\033[48;5;23m'

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

strip_len() {
  printf "%s" "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -c | tr -d ' '
}

rpad() {
  local text="$1" width="$2"
  local visible
  visible=$(strip_len "$text")
  local pad=$(( width - visible ))
  printf "%s" "$text"
  [ "$pad" -gt 0 ] && printf "%${pad}s" ""
}

# ── Status lines ──────────────────────────────────────────────────────────────
ok()   { printf "  ${GREEN}[${BOLD}OK${R}${GREEN}]${R}   ${WHITE}%s${R}\n"    "$*"; }
fail() { printf "  ${RED}[${BOLD}!!${R}${RED}]${R}   ${WHITE}%s${R}\n"        "$*"; }
warn() { printf "  ${YELLOW}[${BOLD}WW${R}${YELLOW}]${R}   ${YELLOW}%s${R}\n" "$*"; }
info() { printf "  ${GRAY}[${R}${CYAN}--${R}${GRAY}]${R}   ${GRAY}%s${R}\n"   "$*"; }
dbg()  { printf "  ${GRAY}[${R}${MAGENTA}>>${R}${GRAY}]${R}   ${GRAY}%s${R}\n" "$*"; }
hint() { printf "      ${DIM}${GRAY}%s${R}\n"                                  "$*"; }

# ── Key/value row ─────────────────────────────────────────────────────────────
kv() {
  local key="$1" val="$2"
  printf "  ${GRAY}│${R}  ${CYAN}${BOLD}%-14s${R}  ${GRAY}│${R}  ${WHITE}%-*s${R}  ${GRAY}│${R}\n" \
    "$key" "$(( COLS - 28 ))" "$val"
}

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

# ── Matrix rain (FIXED — pure ASCII only) ────────────────────────────────────
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

# ── Banner renderers ──────────────────────────────────────────────────────────
animate_expo_wordmark() {
  local raw=(
    "  ███████╗██╗  ██╗██████╗  ██████╗ "
    "  ██╔════╝╚██╗██╔╝██╔══██╗██╔═══██╗"
    "  █████╗   ╚███╔╝ ██████╔╝██║   ██║"
    "  ██╔══╝   ██╔██╗ ██╔═══╝ ██║   ██║"
    "  ███████╗██╔╝ ██╗██║     ╚██████╔╝"
    "  ╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ "
  )
  local line_cols=("$X1" "$X2" "$X3" "$X4" "$X5" "$X6")
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

render_logo_separator() {
  local label="USB MODE // ADB TUNNEL"
  local line_w=15
  printf "  %b%s%b %b%s%b %b%s%b\n" \
    "${GRAY}${DIM}" "$(repeat_char '.' "$line_w")" "${R}" \
    "${X3}${BOLD}" "$label" "${R}" \
    "${GRAY}${DIM}" "$(repeat_char '.' "$line_w")" "${R}"
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
  printf "${GREEN}$(repeat_char '═' $filled)${R}"
  printf "${GRAY}$(repeat_char '.' $empty)${R}"
  printf "${GRAY}]${R}  ${BOLD}${WHITE}%3d%%${R}  ${GRAY}(%d/%d)${R}\n" \
    "$pct" "$current" "$total"
}

# ── Shutdown animation ───────────────────────────────────────────────────────
shutdown_sequence() {
  local bar_w=24
  local msg="Expo USB session ended"

  gap
  section "SESSION CLOSED"
  gap

  tput civis 2>/dev/null

  for (( i=0; i<=bar_w; i++ )); do
    printf "\r  ${GRAY}[${R}${CYAN}$(repeat_char '═' "$i")${GRAY}$(repeat_char '.' $(( bar_w - i )))${R}${GRAY}]${R}  ${DIM}closing metro bridge${R}"
    sleep 0.018
  done
  printf "\n"

  local frames=(".." "::" "--")
  for frame in "${frames[@]}"; do
    printf "\r  ${GRAY}[${R}${CYAN}%s${R}${GRAY}]${R}   ${GRAY}%s${R}" "$frame" "$msg"
    sleep 0.08
  done
  printf "\r  ${GRAY}[${R}${CYAN}--${R}${GRAY}]${R}   ${GRAY}%s${R}\n" "$msg"

  tput cnorm 2>/dev/null
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
    "${GRAY}FLICKO-BIOS v2.1.0  |  64MB VRAM  |  CPU: USB-CORE x4${R}"
    "${GRAY}Detecting terminal geometry...  ${GREEN}OK${R}"
    "${GRAY}Mounting colour palette...      ${GREEN}OK${R}"
    "${GRAY}Loading ADB subsystem...        ${GREEN}OK${R}"
    "${GRAY}Initialising Metro launcher...  ${GREEN}OK${R}"
  )
  for bl in "${bios_lines[@]}"; do
    printf "  "
    printf "%b\n" "$bl"
    sleep 0.12
  done
  gap

  # ── Phase 3: segmented progress bar ──────────────────────────────────────
  local phases=("KERNEL   " "ADB      " "METRO    " "DISPLAY  " "READY    ")
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
    printf "  ${GREEN}${BOLD}[ FLICKO USB LAUNCHER — SYSTEM GO ]${R}\n"
    sleep 0.07
    tput cuu1 2>/dev/null
    printf "%${COLS}s\r" ""
    sleep 0.05
  done
  printf "  ${GREEN}${BOLD}[ FLICKO USB LAUNCHER — SYSTEM GO ]${R}\n"
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
printf "  ${CYAN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"
gap

animate_expo_wordmark

gap

render_logo_separator

gap

render_flicko_wordmark

gap

# ── Sub-title ─────────────────────────────────────────────────────────────────
SUBTITLE="[ USB  *  ADB  *  METRO  *  DEVELOPER EDITION  *  v2.1 ]"
SUB_PAD=$(( (COLS - ${#SUBTITLE}) / 2 ))
[ "$SUB_PAD" -lt 0 ] && SUB_PAD=0
printf "%${SUB_PAD}s${GRAY}%s${R}\n" "" "$SUBTITLE"

gap

# ── Timestamp badge ───────────────────────────────────────────────────────────
BADGE="  >> expo-usb v2.1  |  $(date '+%Y-%m-%d %H:%M:%S')  "
BADGE_PAD=$(( (COLS - ${#BADGE}) / 2 ))
[ "$BADGE_PAD" -lt 0 ] && BADGE_PAD=0
printf "%${BADGE_PAD}s${BG_DARK}${CYAN}${BOLD}%s${R}\n" "" "$BADGE"

gap
printf "  ${CYAN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"

tput cnorm 2>/dev/null

# ─────────────────────────────────────────────────────────────────────────────
#  ENVIRONMENT TABLE
# ─────────────────────────────────────────────────────────────────────────────
section "SYSTEM ENVIRONMENT"
gap

start_spinner "Probing environment..."

NODE_VER=$(node  --version 2>/dev/null || echo "not found")
NPM_VER=$(npm   --version  2>/dev/null || echo "not found")
ADB_VER=$(adb   version    2>/dev/null \
            | head -1 \
            | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
            | head -1 \
            || echo "not found")
EXPO_VER=$(npx expo --version 2>/dev/null || echo "not found")
OS_STR="$(uname -s) $(uname -r | cut -d- -f1)"

stop_spinner

TABLE_INNER=$(( COLS - 4 ))
printf "  ${GRAY}+$(repeat_char '─' 16)+$(repeat_char '─' $(( TABLE_INNER - 19 )))+${R}\n"
printf "  ${GRAY}|${R}  ${CYAN}${BOLD}%-14s${R}  ${GRAY}|${R}  ${CYAN}${BOLD}%-*s${R}  ${GRAY}|${R}\n" \
  "KEY" "$(( TABLE_INNER - 23 ))" "VALUE"
printf "  ${GRAY}+$(repeat_char '─' 16)+$(repeat_char '─' $(( TABLE_INNER - 19 )))+${R}\n"

kv "Project"   "$(basename "$SCRIPT_DIR")"
kv "Path"      "$SCRIPT_DIR"
kv "Node.js"   "$NODE_VER"
kv "npm"       "$NPM_VER"
kv "Expo CLI"  "$EXPO_VER"
kv "ADB"       "$ADB_VER"
kv "Shell"     "$(basename "$SHELL")"
kv "OS"        "$OS_STR"

printf "  ${GRAY}+$(repeat_char '─' 16)+$(repeat_char '─' $(( TABLE_INNER - 19 )))+${R}\n"

gap
[ "$NODE_VER" != "not found" ] && ok "Node.js reachable  ${GRAY}(${NODE_VER})${R}" \
                                 || fail "Node.js NOT found in PATH"
[ "$ADB_VER"  != "not found" ] && ok "ADB reachable  ${GRAY}(${ADB_VER})${R}"    \
                                 || fail "ADB NOT found — install android-tools"
[ "$EXPO_VER" != "not found" ] && ok "Expo CLI reachable  ${GRAY}(${EXPO_VER})${R}" \
                                 || warn "Expo CLI not detected globally"

# ─────────────────────────────────────────────────────────────────────────────
#  DEVICE DETECTION
# ─────────────────────────────────────────────────────────────────────────────
section "ANDROID DEVICE"
gap

start_spinner "Scanning USB bus for ADB devices..."
sleep 0.6
ADB_OUT="$(adb devices 2>&1)"
DEVICE_LINE="$(printf "%s" "$ADB_OUT" | grep -E 'device$' | head -1)"
DEVICE_ID="$(printf "%s" "$DEVICE_LINE" | awk '{print $1}')"
stop_spinner

if [ -z "$DEVICE_LINE" ]; then
  fail "No authorised Android device found"
  gap

  printf "  ${RED}$(repeat_char '─' $(( COLS - 4 )))${R}\n"
  printf "  ${BOLD}${YELLOW}TROUBLESHOOTING CHECKLIST${R}\n"
  printf "  ${RED}$(repeat_char '─' $(( COLS - 4 )))${R}\n"
  gap

  step_label 1 "Connect phone via ${BOLD}data-capable${R} USB cable"
  step_label 2 "Settings > About Phone — tap Build Number x7"
  step_label 3 "Settings > Developer Options — enable ${BOLD}USB Debugging${R}"
  step_label 4 "Tap ${BOLD}Allow${R} on the device authorization popup"
  step_label 5 "Run ${CYAN}adb devices${R} to confirm"

  gap
  printf "  ${BG_RED}${BOLD}${WHITE}  [!!]  ABORT — no device connected  ${R}\n"
  gap
  exit 1
fi

ok "Device detected on USB"
gap

start_spinner "Reading device properties via ADB..."
MODEL="$(adb -s "$DEVICE_ID"   shell getprop ro.product.model          2>/dev/null | tr -d '\r\n')"
BRAND="$(adb -s "$DEVICE_ID"   shell getprop ro.product.brand          2>/dev/null | tr -d '\r\n')"
ANDROID="$(adb -s "$DEVICE_ID" shell getprop ro.build.version.release  2>/dev/null | tr -d '\r\n')"
API="$(adb -s "$DEVICE_ID"     shell getprop ro.build.version.sdk      2>/dev/null | tr -d '\r\n')"
BATTERY="$(adb -s "$DEVICE_ID" shell dumpsys battery 2>/dev/null \
            | grep 'level:' | awk '{print $2}' | tr -d '\r\n' | sed 's/[^0-9]//g')"
CONN="$(adb -s "$DEVICE_ID"    shell dumpsys battery 2>/dev/null \
            | grep 'USB powered:' | awk '{print $3}' | tr -d '\r\n')"
stop_spinner

# Battery bar — safe ASCII only
BAT_BAR=""
if [ -n "$BATTERY" ]; then
  local_bat=$(( BATTERY / 10 ))
  for (( b=0; b<10; b++ )); do
    if [ "$b" -lt "$local_bat" ]; then
      [ "$BATTERY" -le 20 ] && BAT_BAR+="${RED}|${R}" || BAT_BAR+="${GREEN}|${R}"
    else
      BAT_BAR+="${GRAY}.${R}"
    fi
  done
  BAT_BAR="${BAT_BAR}  ${WHITE}${BATTERY}%${R}"
fi

# Device info card
CARD_W=$(( COLS - 4 ))
gap
printf "  ${CYAN}+$(repeat_char '─' $(( CARD_W - 2 )))+${R}\n"

DEVICE_TITLE="${BRAND} ${MODEL}"
printf "  ${CYAN}|${R}  ${BOLD}${WHITE}%-*s${R}  ${CYAN}|${R}\n" \
  "$(( CARD_W - 6 ))" "$DEVICE_TITLE"

printf "  ${CYAN}+$(repeat_char '─' $(( CARD_W - 2 )))+${R}\n"

printf "  ${CYAN}|${R}  ${GRAY}%-12s${R}  ${WHITE}%-*s${R}  ${CYAN}|${R}\n" \
  "Android" "$(( CARD_W - 21 ))" "v${ANDROID}  (API ${API})"

printf "  ${CYAN}|${R}  ${GRAY}%-12s${R}  ${WHITE}%-*s${R}  ${CYAN}|${R}\n" \
  "Device ID" "$(( CARD_W - 21 ))" "${DEVICE_ID}"

printf "  ${CYAN}|${R}  ${GRAY}%-12s${R}  ${WHITE}%-*s${R}  ${CYAN}|${R}\n" \
  "USB Power" "$(( CARD_W - 21 ))" "${CONN:-unknown}"

if [ -n "$BATTERY" ]; then
  printf "  ${CYAN}|${R}  ${GRAY}%-12s${R}  %b  ${CYAN}|${R}\n" \
    "Battery" "$BAT_BAR"
fi

printf "  ${CYAN}+$(repeat_char '─' $(( CARD_W - 2 )))+${R}\n"
gap

# ─────────────────────────────────────────────────────────────────────────────
#  PORT FORWARDING
# ─────────────────────────────────────────────────────────────────────────────
section "PORT FORWARDING"
gap

dbg "Setting up ADB reverse tunnels..."
gap

PORTS=(8081 8082 19000 19001)
TOTAL=${#PORTS[@]}
DONE=0
FAILED=0

for PORT in "${PORTS[@]}"; do
  start_spinner "tcp:${PORT} -> device:${PORT}"
  sleep 0.25

  if adb reverse "tcp:${PORT}" "tcp:${PORT}" &>/dev/null; then
    stop_spinner
    DONE=$(( DONE + 1 ))
    ok "tcp:${PORT}  -->  device:${PORT}  ${GREEN}[ACTIVE]${R}"
  else
    stop_spinner
    FAILED=$(( FAILED + 1 ))
    warn "tcp:${PORT}  --x  could not forward"
  fi
  progress_bar "$(( DONE + FAILED ))" "$TOTAL"
done

gap

if adb reverse --list 2>/dev/null | grep -q '8081'; then
  printf "  ${BG_GREEN}${BOLD}${WHITE}  [OK]  Port 8081 verified — tunnel is live  ${R}\n"
else
  printf "  ${BG_RED}${BOLD}${WHITE}  [!!]  Port 8081 verification failed        ${R}\n"
fi

gap
dbg "Forwarded ${DONE}/${TOTAL} ports  |  ${FAILED} failed"

# ─────────────────────────────────────────────────────────────────────────────
#  CONNECTION GUIDE
# ─────────────────────────────────────────────────────────────────────────────
section "CONNECTION GUIDE"
gap

step_label 1 "Open ${BOLD}Expo Go${R} on your Android device"
step_label 2 "Tap ${BOLD}Enter URL manually${R}"
step_label 3 "Enter  ${CYAN}${BOLD}exp://127.0.0.1:8081${R}"
step_label 4 "Tap ${BOLD}Connect${R} and wait for JS bundle to load"

gap
info "QR code will also appear in Metro output below"
info "Charge-only cables will NOT work — use a data cable"
info "If stuck:  ${CYAN}adb reverse --list${R}  to inspect tunnels"
info "Force reload in app:  ${CYAN}Shake device > Reload${R}"
gap

# ─────────────────────────────────────────────────────────────────────────────
#  LAUNCH SEQUENCE
# ─────────────────────────────────────────────────────────────────────────────
section "LAUNCH"
gap

glitch_text "Initialising Metro Bundler..."
sleep 0.15

printf "  ${GREEN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"
gap
printf "  ${BOLD}${GREEN}>>  ${R}"
type_text "npx expo start --localhost --clear" 0.03
gap
printf "  ${GRAY}Keybindings:  ${CYAN}r${R}${GRAY} reload  |  ${CYAN}a${R}${GRAY} Android  |  ${CYAN}Ctrl+C${R}${GRAY} quit${R}\n"
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
npx expo start --localhost --clear
EXPO_STATUS=$?
shutdown_sequence
exit "$EXPO_STATUS"