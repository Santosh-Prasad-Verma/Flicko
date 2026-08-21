#!/usr/bin/env bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║              Flicko — Setup Wizard  ✦  Enhanced Edition                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  COLOURS & STYLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
UNDERLINE=$'\033[4m'
BLINK=$'\033[5m'

WHITE=$'\033[97m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
RED=$'\033[91m'
MAGENTA=$'\033[95m'
BLUE=$'\033[94m'
GRAY=$'\033[90m'
BLACK=$'\033[30m'
ORANGE=$'\033[38;5;208m'

# 256-colour gradient palette  (magenta → cyan arc)
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
TEAL=$'\033[38;5;51m'
LIME=$'\033[38;5;118m'
GOLD=$'\033[38;5;220m'
ROSE=$'\033[38;5;204m'

# Background colours
BG_DARK=$'\033[48;5;234m'
BG_DARKER=$'\033[48;5;232m'
BG_BLACK=$'\033[40m'
BG_GREEN=$'\033[48;5;22m'
BG_DARK_GREEN=$'\033[48;5;28m'
BG_RED=$'\033[48;5;52m'
BG_PURPLE=$'\033[48;5;57m'
BG_NAVY=$'\033[48;5;17m'
BG_TEAL=$'\033[48;5;23m'
BG_ORANGE=$'\033[48;5;130m'
BG_YELLOW=$'\033[48;5;136m'
BG_GRAY=$'\033[48;5;237m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  TERMINAL GEOMETRY  (hard-capped at 90)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
COLS=$(tput cols 2>/dev/null || echo 80)
ROWS=$(tput lines 2>/dev/null || echo 24)
[ "$COLS" -gt 90 ] && COLS=90

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  CORE HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
gap()  { printf "\n"; }
gap2() { printf "\n\n"; }

repeat_char() {
  local char="$1" count="$2" out=""
  for (( i=0; i<count; i++ )); do out+="$char"; done
  printf "%s" "$out"
}

center_text() {
  local text="$1" width="${2:-$COLS}"
  local pad=$(( (width - ${#text}) / 2 ))
  [ "$pad" -lt 0 ] && pad=0
  printf "%${pad}s%s\n" "" "$text"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  STATUS LINES  (upgraded icons)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ok()   { printf "  ${BG_DARK}${GREEN} ✔ ${R}${GREEN}${BOLD} %-*s${R}\n" "$(( COLS - 9 ))" "$*"; }
fail() { printf "  ${BG_RED}${WHITE} ✘ ${R}${RED}${BOLD}  %-*s${R}\n"   "$(( COLS - 9 ))" "$*"; }
warn() { printf "  ${BG_YELLOW}${BLACK} ⚠ ${R}${YELLOW}  %-*s${R}\n"   "$(( COLS - 9 ))" "$*"; }
info() { printf "  ${GRAY}  ℹ  ${CYAN}%s${R}\n"                          "$*"; }
dbg()  { printf "  ${GRAY}  ›  ${DIM}${GRAY}%s${R}\n"                    "$*"; }
hint() { printf "      ${DIM}${GRAY}↳  %s${R}\n"                         "$*"; }
note() { printf "  ${BG_NAVY}${CYAN}${BOLD} NOTE ${R}  ${WHITE}%s${R}\n" "$*"; }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  DIVIDERS & SECTION HEADERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
thin_line()  { printf "  ${GRAY}$(repeat_char '─' $(( COLS - 4 )))${R}\n"; }
thick_line() { printf "  ${CYAN}$(repeat_char '═' $(( COLS - 4 )))${R}\n"; }
wave_line()  {
  local w=$(( COLS - 4 ))
  local wave="${M}"
  local palette=("$M" "$MP" "$P" "$PB" "$B" "$BB" "$CB" "$C")
  printf "  "
  for (( i=0; i<w; i++ )); do
    local ci=$(( i % ${#palette[@]} ))
    printf "%b%s" "${palette[$ci]}" "─"
  done
  printf "${R}\n"
}

section() {
  local title="$1"
  local icon="${2:-◈}"
  local rhs=$(( COLS - ${#title} - 12 ))
  [ "$rhs" -lt 1 ] && rhs=1
  gap
  printf "  ${CB}$(repeat_char '─' 2)${R} ${BG_DARK}${BOLD}${C} ${icon} ${WHITE}${title} ${R}${CB}$(repeat_char '─' $rhs)${R}\n"
  gap
}

subsection() {
  local title="$1"
  printf "  ${GRAY}  ┌─ ${CYAN}${BOLD}${title}${R}\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  NUMBERED STEP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step_label() {
  local n="$1" msg="$2"
  printf "  ${BG_PURPLE}${BOLD}${WHITE} %02d ${R}  %b\n" "$n" "$msg"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  TYPING ANIMATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
type_text() {
  local text="$1" delay="${2:-0.022}"
  for (( i=0; i<${#text}; i++ )); do
    printf "%s" "${text:$i:1}"
    sleep "$delay"
  done
  printf "\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GLITCH ANIMATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
glitch_text() {
  local text="$1"
  local len=${#text}
  local glitch_chars="@#%&?!><~^*"
  for (( round=0; round<6; round++ )); do
    local out=""
    for (( i=0; i<len; i++ )); do
      if (( RANDOM % 4 == 0 )); then
        local gi=$(( RANDOM % ${#glitch_chars} ))
        out+="${RED}${glitch_chars:$gi:1}${R}"
      elif (( RANDOM % 6 == 0 )); then
        out+="${CYAN}${text:$i:1}${R}"
      else
        out+="${text:$i:1}"
      fi
    done
    printf "\r  ${BOLD}${M}%b${R}" "$out"
    sleep 0.055
  done
  printf "\r  ${BOLD}${GREEN}%s${R}\n" "$text"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  MATRIX RAIN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
matrix_burst() {
  local width=$(( COLS - 4 ))
  local cols_count=7
  local col_width=$(( width / cols_count ))
  local all_cols=()
  local col_colors=("$M" "$MP" "$P" "$B" "$CB" "$C" "$TEAL")

  for (( c=0; c<cols_count; c++ )); do
    all_cols+=( $(( RANDOM % 5 )) )
  done

  tput civis 2>/dev/null

  for (( row=0; row<8; row++ )); do
    local line="  "
    for (( c=0; c<cols_count; c++ )); do
      local drop=${all_cols[$c]}
      local ccol="${col_colors[$c]}"
      for (( w=0; w<col_width; w++ )); do
        local dist=$(( row - drop ))
        if   (( dist == 0 ));               then line+="${BOLD}${WHITE}"
        elif (( dist > 0 && dist < 2 ));    then line+="${BOLD}${ccol}"
        elif (( dist >= 2 && dist < 4 ));   then line+="${ccol}"
        else                                     line+="${GRAY}${DIM}"
        fi
        local rn=$(( RANDOM % 62 ))
        if   (( rn < 10 )); then
          line+="$rn"
        elif (( rn < 36 )); then
          line+="$(printf "\\$(printf '%03o' $(( rn - 10 + 65 )))")"
        else
          line+="$(printf "\\$(printf '%03o' $(( rn - 36 + 97 )))")"
        fi
        line+="${R}"
      done
    done
    printf "%b\n" "$line"
    sleep 0.048

    for (( c=0; c<cols_count; c++ )); do
      if (( RANDOM % 2 == 0 )); then
        all_cols[$c]=$(( all_cols[$c] + 1 ))
      fi
    done
  done

  tput cnorm 2>/dev/null
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  FLICKO WORDMARK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  SPINNER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SPINNER_PID=""

start_spinner() {
  local msg="$1"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local spin_colors=("$M" "$MP" "$P" "$B" "$CB" "$C")
  (
    local i=0 ci=0
    tput civis 2>/dev/null
    while true; do
      printf "\r  ${spin_colors[$ci]}${frames[$i]}${R}  ${GRAY}${msg}${R}   "
      i=$(( (i + 1) % ${#frames[@]} ))
      ci=$(( (ci + 1) % ${#spin_colors[@]} ))
      sleep 0.065
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  PROGRESS BAR  (gradient fill)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
progress_bar() {
  local current="$1" total="$2"
  local bar_w=42
  local filled=$(( current * bar_w / total ))
  local empty=$(( bar_w - filled ))
  local pct=$(( current * 100 / total ))
  local grad=("$M" "$MP" "$P" "$B" "$CB" "$C" "$TEAL" "$GREEN")

  printf "  ${GRAY}╟${R}"
  for (( i=0; i<filled; i++ )); do
    local ci=$(( i * ${#grad[@]} / bar_w ))
    printf "%b▓" "${grad[$ci]}"
  done
  printf "${GRAY}$(repeat_char '░' $empty)╢${R}"

  if   (( pct == 100 )); then printf "  ${GREEN}${BOLD}%3d%%  ✔${R}" "$pct"
  elif (( pct >= 60  )); then printf "  ${CYAN}${BOLD}%3d%%${R}"      "$pct"
  else                        printf "  ${YELLOW}${BOLD}%3d%%${R}"    "$pct"
  fi

  printf "  ${GRAY}(%d/%d)${R}\n" "$current" "$total"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  BOOT SEQUENCE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
boot_sequence() {
  clear
  tput civis 2>/dev/null

  local w=$(( COLS - 4 ))
  local scan_pal=("$M" "$MP" "$P" "$B" "$BB" "$CB" "$C")

  # ── Phase 1: BIOS boot messages ──────────────────────────────────────────
  printf "  ${BG_DARK}${CYAN}${BOLD} ◈  FLICKO-BIOS v2.1.0  │  64 MB VRAM  │  SETUP-CORE ×4 ${R}\n"
  gap

  local bios=(
    "${GRAY}├─ Detecting terminal geometry  .............. ${GREEN}${BOLD}OK${R}"
    "${GRAY}├─ Mounting 256-colour palette  .............. ${GREEN}${BOLD}OK${R}"
    "${GRAY}├─ Initialising animation engine  ............ ${GREEN}${BOLD}OK${R}"
    "${GRAY}├─ Loading prerequisite scanner  ............. ${GREEN}${BOLD}OK${R}"
    "${GRAY}└─ Preparing setup manifest  ................. ${GREEN}${BOLD}OK${R}"
  )
  for line in "${bios[@]}"; do
    printf "  "
    printf "%b\n" "$line"
    sleep 0.1
  done
  gap

  # ── Phase 2: segmented gradient progress bar ──────────────────────────────
  local phases=("KERNEL " "MODULES" "SERVICES" "DISPLAY" " READY ")
  local pcols=("$M" "$P" "$B" "$CB" "$GREEN")
  local bar_w=$(( w - 18 ))
  local total=${#phases[@]}

  for (( p=0; p<total; p++ )); do
    local label="${phases[$p]}"
    local col="${pcols[$p]}"
    local steps=$(( bar_w / total ))
    local start=$(( p * steps ))
    local end=$(( start + steps ))
    [ "$p" -eq $(( total - 1 )) ] && end=$bar_w

    for (( s=start; s<=end; s++ )); do
      local empty=$(( bar_w - s ))
      local pct=$(( s * 100 / bar_w ))
      local bar=""
      for (( b=0; b<s; b++ )); do
        local si=$(( b * total / bar_w ))
        bar+="${pcols[$si]}▓${R}"
      done
      printf "\r  ${col}${BOLD}[%s]${R}  ${GRAY}║${R}%b${GRAY}$(repeat_char '░' $empty)║${R}  ${BOLD}${WHITE}%3d%%${R}" \
        "$label" "$bar" "$pct"
      sleep 0.010
    done
  done
  printf "\n"
  gap

  # ── Phase 3: flash banner ─────────────────────────────────────────────────
  local banner="  ✦  FLICKO SETUP ENGINE  —  ALL SYSTEMS GO  ✦"
  for (( f=0; f<3; f++ )); do
    local bc="${scan_pal[$((f % ${#scan_pal[@]}))]}"
    printf "  ${BG_DARK}${bc}${BOLD}%-*s${R}\n" "$w" "$banner"
    sleep 0.08
    tput cuu1 2>/dev/null
    printf "%${COLS}s\r" ""
    sleep 0.04
  done
  printf "  ${BG_DARK}${GREEN}${BOLD}%-*s${R}\n" "$w" "$banner"
  sleep 0.4

  tput cnorm 2>/dev/null
  sleep 0.15
  clear
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ❱  RUN BOOT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
boot_sequence

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  MAIN SCREEN HEADER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
tput civis 2>/dev/null
matrix_burst
gap
wave_line
gap

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ICON LOGO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
  sleep 0.03
done
gap

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  WORD-MARK LOGO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
render_flicko_wordmark
gap

# ── Sub-title ─────────────────────────────────────────────────────────────────
SUBTITLE="◈  REAL-TIME  ·  COMMUNITY  ·  PLATFORM  ·  v1.0.0  ◈"
SUB_PAD=$(( (COLS - ${#SUBTITLE}) / 2 ))
[ "$SUB_PAD" -lt 0 ] && SUB_PAD=0
printf "%${SUB_PAD}s${BOLD}${GRAY}%s${R}\n" "" "$SUBTITLE"
gap

# ── Timestamp badge ───────────────────────────────────────────────────────────
TS="$(date '+%Y-%m-%d  %H:%M:%S')"
BADGE=" ◈  flicko-setup  │  ${TS}  │  PID $$  "
BADGE_PAD=$(( (COLS - ${#BADGE}) / 2 ))
[ "$BADGE_PAD" -lt 0 ] && BADGE_PAD=0
printf "%${BADGE_PAD}s${BG_DARK}${BOLD}${C}%s${R}\n" "" "$BADGE"
gap

wave_line
tput cnorm 2>/dev/null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  PROJECT INFO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
section "PROJECT" "◈"

printf "  ${BG_DARK}${BOLD}${WHITE}  Flicko${R}${BG_DARK}${GRAY}  —  Discord-inspired real-time community platform  ${R}\n"
gap

TABLE_W=$(( COLS - 4 ))
local_w=$(( TABLE_W - 19 ))

# Table header
printf "  ${GRAY}┌$(repeat_char '─' $(( TABLE_W - 2 )))┐${R}\n"
printf "  ${GRAY}│${R}  ${BG_DARK}${BOLD}${C}%-12s${R}${BG_DARK}  ${GRAY}│${R}${BG_DARK}  ${BOLD}${WHITE}%-*s${R}${BG_DARK}  ${GRAY}│${R}\n" \
  " LAYER" "$(( local_w - 2 ))" "TECHNOLOGY STACK"
printf "  ${GRAY}├$(repeat_char '─' $(( TABLE_W - 2 )))┤${R}\n"

_row() {
  local label="$1" value="$2" lcolor="${3:-$CYAN}" vcolor="${4:-$WHITE}"
  printf "  ${GRAY}│${R}  ${lcolor}${BOLD}%-12s${R}  ${GRAY}│${R}  ${vcolor}%-*s${R}  ${GRAY}│${R}\n" \
    "$label" "$local_w" "$value"
}

_row " FRONTEND"  "Flutter  ·  Riverpod  ·  Dart"              "$M"    "$WHITE"
printf "  ${GRAY}├$(repeat_char '─' $(( TABLE_W - 2 )))┤${R}\n"
_row " BACKEND"   "Go  ·  ws-gateway  ·  msg-service"             "$CB"   "$WHITE"
printf "  ${GRAY}├$(repeat_char '─' $(( TABLE_W - 2 )))┤${R}\n"
_row " INFRA"     "Azure  ·  Redis  ·  Docker  ·  ACS"            "$B"    "$WHITE"
printf "  ${GRAY}├$(repeat_char '─' $(( TABLE_W - 2 )))┤${R}\n"
_row " OBS"       "Prometheus  ·  Grafana  ·  pprof"              "$P"    "$WHITE"
printf "  ${GRAY}├$(repeat_char '─' $(( TABLE_W - 2 )))┤${R}\n"
_row " LICENSE"   "Apache 2.0"                                    "$MP"   "${GRAY}"
printf "  ${GRAY}└$(repeat_char '─' $(( TABLE_W - 2 )))┘${R}\n"

gap
info "github.com/Santosh-Prasad-Verma/Flicko"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  PREREQUISITE CHECKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
section "PREREQUISITE CHECKS" "⬡"

dbg "Scanning \$PATH for required tools..."
gap

PASS=0
FAIL=0
TOTAL_TOOLS=5

# ── tool descriptions ─────────────────────────────────────────────────────────
declare -A TOOL_DESC=(
  [flutter]="Flutter SDK  (mobile app)"
  [go]="Go language runtime  (backend services)"
  [docker]="Container engine  (infra stack)"
  [git]="Version control"
)

check_tool() {
  local name="$1" cmd="$2"
  start_spinner "Checking ${BOLD}${name}${R}${GRAY} — ${TOOL_DESC[$name]:-}${R}..."
  sleep 0.35

  if command -v "$name" &>/dev/null; then
    local ver
    ver=$(eval "$cmd" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' | tr -d '\n')
    stop_spinner
    PASS=$(( PASS + 1 ))
    ok "${BOLD}${name}${R}${GREEN}  ›  ${ver}  ${GRAY}— ${TOOL_DESC[$name]:-}${R}"
  else
    stop_spinner
    FAIL=$(( FAIL + 1 ))
    fail "${BOLD}${name}${R}${RED}  ›  not found in \$PATH  ${GRAY}— ${TOOL_DESC[$name]:-}${R}"
  fi

  progress_bar "$(( PASS + FAIL ))" "$TOTAL_TOOLS"
  gap
}

check_tool "flutter" "flutter --version"
check_tool "go"     "go   version"
check_tool "docker" "docker --version"
check_tool "git"    "git   --version"

# ── result banner ─────────────────────────────────────────────────────────────
thin_line
gap

if [ "$FAIL" -eq 0 ]; then
  glitch_text "All ${PASS}/${TOTAL_TOOLS} prerequisites satisfied — system ready"
  gap
  printf "  ${BG_DARK_GREEN}${BOLD}${WHITE}  ✔  All tools found — proceed to Flicko setup  ${R}\n"
else
  printf "  ${BG_RED}${BOLD}${WHITE}  ✘  ${FAIL} missing tool(s) — install before continuing  ${R}\n"
  gap
  warn "${FAIL} tool(s) not found. Install them then re-run this script."
  gap
  [ ! "$(command -v flutter)"] && hint "flutter      →  https://flutter.dev/docs/get-started"
  [ ! "$(command -v go)"   ] && hint "go          →  https://go.dev/dl"
  [ ! "$(command -v docker)"] && hint "docker      →  https://docs.docker.com/get-docker"
  [ ! "$(command -v git)"  ] && hint "git         →  https://git-scm.com"
fi

gap

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GETTING STARTED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
section "GETTING STARTED" "▶"

# ── Step 1 ────────────────────────────────────────────────────────────────────
step_label 1 "${BOLD}${WHITE}Infrastructure${R}  ${GRAY}— spin up local Redis · Prometheus · Grafana${R}"
gap

printf "  ${GRAY}│${R}\n"
printf "  ${GRAY}│  ${DIM}command:${R}\n"
printf "  ${GRAY}│${R}\n"
printf "  ${GRAY}│  ${BG_DARK}${GREEN}${BOLD}  \$  ${R}${BG_DARK}${WHITE}  "
type_text "./scripts/dev-start.sh" 0.020
printf "${R}"
printf "  ${GRAY}│${R}\n"
info "Starts the full local infra stack via Docker Compose"
note "Requires Docker Desktop to be running"
gap

# ── Step 2 ────────────────────────────────────────────────────────────────────
step_label 2 "${BOLD}${WHITE}Backend Services${R}  ${GRAY}— Go microservices (each in its own terminal)${R}"
gap

printf "  ${GRAY}│${R}\n"
subsection "terminal 1  —  msg-service"
printf "  ${GRAY}│  ${BG_DARK}${GREEN}${BOLD}  \$  ${R}${BG_DARK}${WHITE}  "
type_text "cd services && go run ./msg-service/cmd/server" 0.016
printf "${R}"
gap
subsection "terminal 2  —  ws-gateway"
printf "  ${GRAY}│  ${BG_DARK}${GREEN}${BOLD}  \$  ${R}${BG_DARK}${WHITE}  "
type_text "cd services && go run ./ws-gateway/cmd/gateway" 0.016
printf "${R}"
printf "  ${GRAY}│${R}\n"
info "msg-service   →  http://localhost:8085"
info "ws-gateway    →  ws://localhost:8080"
gap

# ── Step 3 ────────────────────────────────────────────────────────────────────
step_label 3 "${BOLD}${WHITE}Mobile App${R}  ${GRAY}— Flutter client${R}"
gap

printf "  ${GRAY}│${R}\n"
printf "  ${GRAY}│  ${DIM}command:${R}\n"
printf "  ${GRAY}│${R}\n"
printf "  ${GRAY}│  ${BG_DARK}${GREEN}${BOLD}  \$  ${R}${BG_DARK}${WHITE}  "
type_text "cd mobile && flutter pub get && flutter run" 0.018
printf "${R}"
printf "  ${GRAY}│${R}\n"
info "Scan the QR code in the Expo Go app"
hint "Press 'a' for Android emulator  ·  'i' for iOS simulator"
gap

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  QUICK REFERENCE TABLE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
section "QUICK REFERENCE" "◉"

REF_W=$(( COLS - 4 ))
REF_NAME_W=25
REF_DESC_W=$(( REF_W - REF_NAME_W - 11 ))

printf "  ${GRAY}┌$(repeat_char '─' $(( REF_W - 2 )))┐${R}\n"
printf "  ${GRAY}│${R}  ${BG_DARK}${BOLD}${C}%-25s${R}${BG_DARK}  ${GRAY}│${R}${BG_DARK}  ${BOLD}${WHITE}%-*s${R}${BG_DARK}  ${GRAY}│${R}\n" \
  " FILE / SCRIPT" "$REF_DESC_W" "PURPOSE"
printf "  ${GRAY}├$(repeat_char '─' $(( REF_W - 2 )))┤${R}\n"

_ref() {
  printf "  ${GRAY}│${R}  ${YELLOW}%-25s${R}  ${GRAY}│${R}  ${GRAY}%-*s${R}  ${GRAY}│${R}\n" \
    "$1" "$REF_DESC_W" "$2"
}

_ref ".env.example"           "copy → .env and fill in your secrets"
printf "  ${GRAY}├$(repeat_char '─' $(( REF_W - 2 )))┤${R}\n"
_ref "docs/README.md"          "full project documentation"
printf "  ${GRAY}├$(repeat_char '─' $(( REF_W - 2 )))┤${R}\n"
_ref "scripts/dev-start.sh"  "spin up local infra (Redis · Prometheus · Grafana)"
printf "  ${GRAY}├$(repeat_char '─' $(( REF_W - 2 )))┤${R}\n"
_ref "scripts/run-backend.sh" "launch all Go services in one shot"
printf "  ${GRAY}└$(repeat_char '─' $(( REF_W - 2 )))┘${R}\n"

gap

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ENVIRONMENT SNAPSHOT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
section "ENVIRONMENT" "◎"

_env() {
  printf "  ${GRAY}  %-16s${R}  ${WHITE}%s${R}\n" "$1" "$2"
}
_env "Shell:"    "${SHELL:-unknown}"
_env "Terminal:" "${TERM:-unknown}"
_env "User:"     "$(whoami 2>/dev/null || echo unknown)"
_env "Hostname:" "$(hostname 2>/dev/null || echo unknown)"
_env "OS:"       "$(uname -srm 2>/dev/null || echo unknown)"
_env "Width:"    "${COLS} cols"

gap

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  FOOTER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
gap
wave_line
gap

REPO="https://github.com/Santosh-Prasad-Verma/Flicko"
REPO_LBL="◈  ${REPO}"
REPO_PAD=$(( (COLS - ${#REPO_LBL} - 1) / 2 ))
[ "$REPO_PAD" -lt 0 ] && REPO_PAD=0
printf "%${REPO_PAD}s${GRAY}◈  ${UNDERLINE}${BOLD}${CYAN}%s${R}\n" "" "$REPO"

gap

CREDIT="Made with ♥ by the Flicko team"
CREDIT_PAD=$(( (COLS - ${#CREDIT}) / 2 ))
[ "$CREDIT_PAD" -lt 0 ] && CREDIT_PAD=0
printf "%${CREDIT_PAD}s${DIM}${GRAY}%s${R}\n" "" "$CREDIT"

gap
wave_line
gap
