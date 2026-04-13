#!/usr/bin/env bash

# Expo LAN Connection Helper
# Starts Expo in LAN mode with Flicko-branded instructions

# ── Colours ───────────────────────────────────────────────────────────────────
R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

WHITE=$'\033[97m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
GRAY=$'\033[90m'

X1=$'\033[38;5;51m'
X2=$'\033[38;5;45m'
X3=$'\033[38;5;39m'
X4=$'\033[38;5;33m'
X5=$'\033[38;5;27m'
X6=$'\033[38;5;24m'

BG_DARK=$'\033[48;5;234m'

# ── Terminal width ────────────────────────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 72)
[ "$COLS" -gt 86 ] && COLS=86

# ── Core helpers ──────────────────────────────────────────────────────────────
gap() { printf "\n"; }

repeat_char() {
  local char="$1" count="$2" out=""
  for (( i=0; i<count; i++ )); do out+="$char"; done
  printf "%s" "$out"
}

section() {
  local title="$1"
  local rhs=$(( COLS - ${#title} - 9 ))
  [ "$rhs" -lt 1 ] && rhs=1
  printf "  %b\n" "${CYAN}$(repeat_char '─' 2)[ ${BOLD}${WHITE}${title}${R}${CYAN} ]$(repeat_char '─' "$rhs")${R}"
}

ok()   { printf "  ${GREEN}[${BOLD}OK${R}${GREEN}]${R}   ${WHITE}%s${R}\n" "$*"; }
warn() { printf "  ${YELLOW}[${BOLD}WW${R}${YELLOW}]${R}   ${YELLOW}%s${R}\n" "$*"; }
info() { printf "  ${GRAY}[${R}${CYAN}--${R}${GRAY}]${R}   ${GRAY}%s${R}\n" "$*"; }

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

render_flicko_wordmark_lan() {
  local raw=(
    "  ███████╗  ██╗      ██╗   ██████╗  ██╗  ██╗   ██████╗"
    "  ██╔════╝  ██║      ██║  ██╔════╝  ██║ ██╔╝  ██╔═══██╗"
    "  █████╗    ██║      ██║  ██║       █████╔╝   ██║   ██║"
    "  ██╔══╝    ██║      ██║  ██║       ██╔═██╗   ██║   ██║"
    "  ██║       ███████╗ ██║  ╚██████╗  ██║  ╚██╗ ╚██████╔╝"
    "  ╚═╝       ╚══════╝ ╚═╝   ╚═════╝  ╚═╝   ╚══╝  ╚═════╝"
  )
  local line_cols=("$X2" "$X3" "$X4" "$X5" "$X6" "$GRAY")

  for (( l=0; l<${#raw[@]}; l++ )); do
    printf "%b%s%b\n" "${line_cols[$l]}${BOLD}" "${raw[$l]}" "${R}"
  done
}

render_logo_separator() {
  local label="LAN MODE // LOCAL NETWORK"
  local line_w=14
  printf "  %b%s%b %b%s%b %b%s%b\n" \
    "${GRAY}${DIM}" "$(repeat_char '.' "$line_w")" "${R}" \
    "${X3}${BOLD}" "$label" "${R}" \
    "${GRAY}${DIM}" "$(repeat_char '.' "$line_w")" "${R}"
}

# ── Banner frame ──────────────────────────────────────────────────────────────
print_banner() {
  clear
  printf "  ${CYAN}%s${R}\n" "$(repeat_char '═' $(( COLS - 4 )))"
  gap
  animate_expo_wordmark
  gap
  render_logo_separator
  gap
  render_flicko_wordmark_lan
  gap

  local subtitle="[ LAN  *  EXPO GO  *  SAME WIFI  *  DEVELOPER EDITION ]"
  local pad=$(( (COLS - ${#subtitle}) / 2 ))
  [ "$pad" -lt 0 ] && pad=0
  printf "%${pad}s${GRAY}%s${R}\n" "" "$subtitle"
  gap

  local badge="  >> expo-lan helper  |  $(date '+%Y-%m-%d %H:%M:%S')  "
  pad=$(( (COLS - ${#badge}) / 2 ))
  [ "$pad" -lt 0 ] && pad=0
  printf "%${pad}s${BG_DARK}${CYAN}${BOLD}%s${R}\n" "" "$badge"
  gap
  printf "  ${CYAN}%s${R}\n" "$(repeat_char '═' $(( COLS - 4 )))"
  gap
}

# ── Network helpers ───────────────────────────────────────────────────────────
get_local_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

check_firewall_port() {
  # Avoid blocking on an interactive sudo prompt when this is launched from IDEs.
  if ! command -v firewall-cmd >/dev/null 2>&1; then
    info "firewall-cmd not found; skipping firewall check"
    return
  fi

  local ports=""
  ports="$(firewall-cmd --list-ports 2>/dev/null)"

  if [ -z "$ports" ]; then
    ports="$(sudo -n firewall-cmd --list-ports 2>/dev/null)"
  fi

  if printf "%s" "$ports" | grep -q "8081/tcp"; then
    ok "Firewall port 8081 is OPEN"
  else
    warn "Firewall port 8081 could not be confirmed as open"
    printf "      ${DIM}${GRAY}Run: sudo firewall-cmd --add-port=8081/tcp --permanent && sudo firewall-cmd --reload${R}\n"
  fi
}

# ── Main flow ─────────────────────────────────────────────────────────────────
print_banner

section "LAN DISCOVERY"
gap

LOCAL_IP="$(get_local_ip)"
if [ -n "$LOCAL_IP" ]; then
  ok "Your computer IP is ${CYAN}${BOLD}${LOCAL_IP}${R}"
else
  warn "Could not determine local IP address automatically"
fi

check_firewall_port

gap
section "PHONE INSTRUCTIONS"
gap

printf "  ${WHITE}1.${R} Open ${CYAN}${BOLD}Expo Go${R} on your phone\n"
printf "  ${WHITE}2.${R} Make sure phone and computer are on the ${CYAN}same Wi-Fi${R}\n"
printf "  ${WHITE}3.${R} Tap ${CYAN}Enter URL manually${R} if QR scanning is unavailable\n"
if [ -n "$LOCAL_IP" ]; then
  printf "  ${WHITE}4.${R} Use ${CYAN}${BOLD}exp://%s:8081${R}\n" "$LOCAL_IP"
else
  printf "  ${WHITE}4.${R} Use the LAN URL shown by Expo after startup\n"
fi

gap
section "STARTING EXPO LAN"
gap
info "Launching Metro Bundler in LAN mode..."
gap

npx expo start --lan

gap
section "SESSION CLOSED"
gap
info "Expo LAN session ended"
