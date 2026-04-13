#!/usr/bin/env bash
# =============================================================================
# Flicko — Container Health Check Script
# =============================================================================
set -euo pipefail

# ── Colours & Formatting ──────────────────────────────────────────────────────
R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
WHITE=$'\033[97m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
RED=$'\033[91m'
MAGENTA=$'\033[95m'
BLUE=$'\033[94m'
GRAY=$'\033[90m'

# Extended palette
X1=$'\033[38;5;51m'
X2=$'\033[38;5;45m'
X3=$'\033[38;5;39m'
X4=$'\033[38;5;33m'
X5=$'\033[38;5;27m'
X6=$'\033[38;5;24m'
TEAL=$'\033[38;5;30m'
ORANGE=$'\033[38;5;208m'
PINK=$'\033[38;5;205m'
LBLUE=$'\033[38;5;75m'
MINT=$'\033[38;5;121m'

# Background
BG_DARK=$'\033[48;5;232m'
BG_PANEL=$'\033[48;5;234m'
BG_HEADER=$'\033[48;5;17m'

COLS=$(tput cols 2>/dev/null || echo 100)
[ "$COLS" -lt 90 ] && COLS=100

# ── Table column widths ───────────────────────────────────────────────────────
C1=28   # container
C2=14   # status
C3=16   # health
C4=14   # uptime
C5=9    # restarts
# Total inner = 28+14+16+14+9 = 81, + 6 separators = 87
TABLE_W=$(( C1 + C2 + C3 + C4 + C5 + 6 ))

# ── Helpers ───────────────────────────────────────────────────────────────────
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

pad_center() {
  # pad_center "text" width → returns string padded to width, centered
  local text="$1" width="$2"
  local tlen=${#text}
  local lpad=$(( (width - tlen) / 2 ))
  local rpad=$(( width - tlen - lpad ))
  [ "$lpad" -lt 0 ] && lpad=0
  [ "$rpad" -lt 0 ] && rpad=0
  printf "%${lpad}s%s%${rpad}s" "" "$text" ""
}

strip_ansi() {
  printf "%s" "$1" | sed -E $'s/\x1B\\[[0-9;]*[[:alpha:]]//g'
}

visible_length() {
  local plain
  plain=$(strip_ansi "$1")
  printf "%s" "${#plain}"
}

pad_visible_right() {
  local text="$1" width="$2" len pad
  len=$(visible_length "$text")
  pad=$(( width - len ))
  [ "$pad" -lt 0 ] && pad=0
  printf "%s%${pad}s" "$text" ""
}

pad_visible_center() {
  local text="$1" width="$2" len lpad rpad
  len=$(visible_length "$text")
  lpad=$(( (width - len) / 2 ))
  rpad=$(( width - len - lpad ))
  [ "$lpad" -lt 0 ] && lpad=0
  [ "$rpad" -lt 0 ] && rpad=0
  printf "%${lpad}s%s%${rpad}s" "" "$text" ""
}

ok()   { printf "  ${GREEN}${BOLD}✔${R}  ${WHITE}%s${R}\n"    "$*"; }
fail() { printf "  ${RED}${BOLD}✗${R}  ${WHITE}%s${R}\n"      "$*"; }
warn() { printf "  ${YELLOW}${BOLD}⚠${R}  ${YELLOW}%s${R}\n"  "$*"; }
info() { printf "  ${CYAN}${BOLD}◈${R}  ${GRAY}%s${R}\n"      "$*"; }
hint() { printf "      ${DIM}${GRAY}↳ %s${R}\n"               "$*"; }

# ── Box drawing helpers ───────────────────────────────────────────────────────
# box_top   <width> <color>
# box_mid   <width> <color>
# box_bot   <width> <color>
# box_div   <width> <col1> <col2> <col3> <col4> <col5>  (5-column divider)

box_top() {
  local w="$1" col="${2:-$CYAN}"
  printf "  %b╔%s╗%b\n" "$col" "$(repeat_char '═' $((w-2)))" "$R"
}
box_bot() {
  local w="$1" col="${2:-$CYAN}"
  printf "  %b╚%s╝%b\n" "$col" "$(repeat_char '═' $((w-2)))" "$R"
}
box_mid() {
  local w="$1" col="${2:-$CYAN}"
  printf "  %b╠%s╣%b\n" "$col" "$(repeat_char '═' $((w-2)))" "$R"
}
box_row() {
  local content="$1" w="$2" col="${3:-$CYAN}" textcol="${4:-$WHITE}"
  local inner=$(( w - 2 ))
  printf "  %b║%b%-*s%b%b║%b\n" "$col" "$textcol" "$inner" "$content" "$R" "$col" "$R"
}

box_row_visible() {
  local content="$1" w="$2" col="${3:-$CYAN}"
  local inner=$(( w - 2 ))
  printf "  %b║%b%s%b║%b\n" "$col" "$R" "$(pad_visible_right "$content" "$inner")" "$col" "$R"
}

box_row_center_visible() {
  local content="$1" w="$2" col="${3:-$CYAN}"
  local inner=$(( w - 2 ))
  printf "  %b║%b%s%b║%b\n" "$col" "$R" "$(pad_visible_center "$content" "$inner")" "$col" "$R"
}

# 5-column table divider: ╠═══╬═══╬═══╬═══╬═══╬═══╣
table_div() {
  local top="${1:-╠}" mid="${2:-╬}" bot="${3:-╣}" hchar="${4:-═}" col="${5:-$CYAN}"
  printf "  %b%s%s%s%s%s%s%s%s%s%s%s%b\n" \
    "$col" \
    "$top" "$(repeat_char $hchar $C1)" \
    "$mid" "$(repeat_char $hchar $C2)" \
    "$mid" "$(repeat_char $hchar $C3)" \
    "$mid" "$(repeat_char $hchar $C4)" \
    "$mid" "$(repeat_char $hchar $C5)" \
    "$bot" "$R"
}

# ── Spinner ───────────────────────────────────────────────────────────────────
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
spinner_pid=""

start_spinner() {
  local msg="$1"
  (
    local i=0
    while true; do
      printf "\r  ${CYAN}${SPINNER_FRAMES[$((i % 10))]}${R}  ${GRAY}%s${R}  " "$msg"
      i=$(( i + 1 ))
      sleep 0.08
    done
  ) &
  spinner_pid=$!
  disown "$spinner_pid" 2>/dev/null || true
}

stop_spinner() {
  if [[ -n "$spinner_pid" ]]; then
    kill "$spinner_pid" 2>/dev/null || true
    wait "$spinner_pid" 2>/dev/null || true
    spinner_pid=""
    printf "\r\033[2K"
  fi
}

# ── Glitch text ───────────────────────────────────────────────────────────────
glitch_text() {
  local text="$1" col="${2:-$GREEN}"
  local len=${#text}
  local glitch_chars="@#%&?!▓░▒"
  for (( round=0; round<5; round++ )); do
    local out=""
    for (( i=0; i<len; i++ )); do
      if (( RANDOM % 4 == 0 )); then
        local gi=$(( RANDOM % ${#glitch_chars} ))
        out+="${RED}${glitch_chars:$gi:1}${R}"
      else
        out+="${col}${BOLD}${text:$i:1}${R}"
      fi
    done
    printf "\r  %b" "$out"
    sleep 0.04
  done
  printf "\r  ${col}${BOLD}%s${R}\n" "$text"
}

type_text() {
  local text="$1" delay="${2:-0.012}" col="${3:-$CYAN}"
  printf "  %b" "$col"
  for (( i=0; i<${#text}; i++ )); do
    printf "%s" "${text:$i:1}"
    sleep "$delay"
  done
  printf "%b\n" "$R"
}

# ── Wordmark ──────────────────────────────────────────────────────────────────
render_flicko_wordmark() {
  local raw=(
    "  ███████╗██╗     ██╗ ██████╗██╗  ██╗ ██████╗    ██╗  ██╗███████╗ █████╗ ██╗     ████████╗██╗  ██╗"
    "  ██╔════╝██║     ██║██╔════╝██║ ██╔╝██╔═══██╗   ██║  ██║██╔════╝██╔══██╗██║     ╚══██╔══╝██║  ██║"
    "  █████╗  ██║     ██║██║     █████╔╝ ██║   ██║   ███████║█████╗  ███████║██║        ██║   ███████║"
    "  ██╔══╝  ██║     ██║██║     ██╔═██╗ ██║   ██║   ██╔══██║██╔══╝  ██╔══██║██║        ██║   ██╔══██║"
    "  ██║     ███████╗██║╚██████╗██║  ██╗╚██████╔╝   ██║  ██║███████╗██║  ██║███████╗   ██║   ██║  ██║"
    "  ╚═╝     ╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝"
  )
  local grad=("$X1" "$X2" "$X3" "$X4" "$X5" "$X6")
  local sweep=("$X1" "$X2" "$X3" "$X4" "$X5" "$X6" "$X5" "$X4" "$X3" "$X2" "$X1" "$X2" "$X3" "$X4" "$X5" "$X6")
  local num=${#raw[@]}

  # First draw
  for (( l=0; l<num; l++ )); do
    printf "%b%s%b\n" "${grad[$l]}${BOLD}" "${raw[$l]}" "$R"
  done

  sleep 0.1

  # Sweep animation (2 passes)
  for (( sw=0; sw<2; sw++ )); do
    for (( l=0; l<num; l++ )); do tput cuu1 2>/dev/null; done
    for (( l=0; l<num; l++ )); do
      local ci=$(( (sw * 4 + l) % ${#sweep[@]} ))
      printf "\r%b%s%b\n" "${sweep[$ci]}${BOLD}" "${raw[$l]}" "$R"
    done
    sleep 0.07
  done

  # Settle on final gradient
  for (( l=0; l<num; l++ )); do tput cuu1 2>/dev/null; done
  for (( l=0; l<num; l++ )); do
    printf "\r%b%s%b\n" "${grad[$l]}${BOLD}" "${raw[$l]}" "$R"
  done
}

# ── Section header ────────────────────────────────────────────────────────────
section() {
  local title="$1" col="${2:-$X3}"
  local inner=$(( TABLE_W - 2 ))
  gap
  printf "  %b╔%s╗%b\n" "$col" "$(repeat_char '═' $inner)" "$R"
  local padded
  padded=$(pad_center " ◈  ${title}  ◈ " "$inner")
  printf "  %b║%b%b%s%b%b║%b\n" "$col" "$R" "${BOLD}${WHITE}" "$padded" "$R" "$col" "$R"
  printf "  %b╚%s╝%b\n" "$col" "$(repeat_char '═' $inner)" "$R"
}

# ── Progress bar ──────────────────────────────────────────────────────────────
progress_bar() {
  local current="$1" total="$2" width="${3:-30}"
  local pct=$(( current * 100 / total ))
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local bar="${GREEN}$(repeat_char '█' $filled)${GRAY}$(repeat_char '░' $empty)${R}"
  printf "%b  %3d%%" "$bar" "$pct"
}

summary_row() {
  local icon="$1" label="$2" color="$3" current="$4" total="$5"
  local label_field progress_field stats_field line

  label_field=$(pad_visible_right "${color}${BOLD}${icon}  ${label}${R}" 11)
  progress_field=$(pad_visible_right "$(progress_bar "$current" "$total" "$PBAR_W")" 26)
  stats_field="${color}${BOLD}${current}${R}${GRAY} / ${total}${R}"
  line="  ${label_field}  ${progress_field}  ${stats_field}"

  box_row_visible "$line" "$TABLE_W" "$X4"
}

# ── Uptime formatter ──────────────────────────────────────────────────────────
format_uptime() {
  local started="$1" state="$2"
  if [[ "$state" != "running" ]]; then echo "—"; return; fi
  local se now up
  se=$(date -d "$started" +%s 2>/dev/null || echo "0")
  now=$(date +%s)
  up=$(( now - se ))
  if   [[ $up -gt 86400 ]]; then echo "$((up/86400))d $((up%86400/3600))h"
  elif [[ $up -gt 3600  ]]; then echo "$((up/3600))h $((up%3600/60))m"
  elif [[ $up -gt 60    ]]; then echo "$((up/60))m $((up%60))s"
  else echo "${up}s"; fi
}

# ── Config ────────────────────────────────────────────────────────────────────
CONTAINERS=(
  "flicko-ws-gateway"
  "flicko-msg-service"
  "flicko-nginx"
  "flicko-prometheus"
  "flicko-grafana"
  "flicko-loki"
)

# ── Parse arguments ───────────────────────────────────────────────────────────
OUTPUT_MODE="table"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)  OUTPUT_MODE="json";  shift ;;
    --quiet) OUTPUT_MODE="quiet"; shift ;;
    -h|--help) echo "Usage: $0 [--json | --quiet]"; exit 0 ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Boot screen (table mode only) ─────────────────────────────────────────────
if [[ "$OUTPUT_MODE" == "table" ]]; then
  clear
  gap2

  render_flicko_wordmark

  gap

  # Decorative subtitle bar
  local_inner=$(( TABLE_W - 2 ))
  printf "  ${X4}$(repeat_char '·' 4)[ ${GRAY}${DIM}CONTAINER HEALTH CHECK SYSTEM${R}${X4} ]$(repeat_char '·' 4)${R}\n"

  gap

  # System info bar
  HOST=$(hostname 2>/dev/null || echo "unknown")
  NOW=$(date "+%Y-%m-%d  %H:%M:%S %Z")
  DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "n/a")
  [[ -z "$DOCKER_VER" ]] && DOCKER_VER="n/a"
  docker_display="$DOCKER_VER"
  [[ "$DOCKER_VER" != "n/a" ]] && docker_display="v$DOCKER_VER"
  host_field=$(printf "%-18.18s" "$HOST")
  time_field=$(printf "%-26.26s" "$NOW")
  docker_field=$(printf "%-10.10s" "$docker_display")
  sysinfo_line="  ${DIM}HOST${R}  ${LBLUE}${host_field}${R}  ${DIM}TIME${R}  ${LBLUE}${time_field}${R}  ${DIM}DOCKER${R}  ${LBLUE}${docker_field}${R}"

  box_top "$TABLE_W" "$GRAY"
  box_row_visible "$sysinfo_line" "$TABLE_W" "$GRAY"
  box_bot "$TABLE_W" "$GRAY"

  gap
  type_text "  ▶  INITIALIZING HEALTH SCAN ON ${#CONTAINERS[@]} TARGET CONTAINERS ..." 0.013 "$X2"
  gap
fi

# ── Execution ─────────────────────────────────────────────────────────────────
START_TS=$(date +%s)
all_ok=1
missing=0
unhealthy=0
healthy_count=0
total=${#CONTAINERS[@]}
results=()
issues=()

for container in "${CONTAINERS[@]}"; do
  if [[ "$OUTPUT_MODE" == "table" ]]; then
    start_spinner "Inspecting  ${BOLD}${WHITE}${container}${R}${GRAY}"
  fi

  output=$(docker inspect \
    --format='{{.State.Status}}|{{.State.Health.Status}}|{{.State.StartedAt}}|{{.RestartCount}}' \
    "$container" 2>/dev/null || echo "missing")

  if [[ "$OUTPUT_MODE" == "table" ]]; then
    stop_spinner
  fi

  if [[ "$output" == "missing" ]]; then
    results+=("$container|missing|none|—|0")
    issues+=("Container not found: $container")
    missing=$(( missing + 1 ))
    all_ok=0
    continue
  fi

  IFS='|' read -r state health started restarts <<< "$output"
  [[ -z "$state" ]] && state="unknown"
  if [[ -z "$health" || "$health" == "<no value>" ]]; then
    if [[ "$state" == "running" ]]; then
      health="running"
    else
      health="none"
    fi
  fi
  [[ -z "$restarts" ]] && restarts=0

  uptime=$(format_uptime "$started" "$state")

  if [[ "$health" == "healthy" ]]; then
    healthy_count=$(( healthy_count + 1 ))
  elif [[ "$health" != "starting" ]]; then
    if [[ "$state" != "running" ]]; then
      all_ok=0
      unhealthy=$(( unhealthy + 1 ))
      issues+=("$container - state: $state / health: $health")
    fi
  fi

  results+=("$container|$state|$health|$uptime|$restarts")
done

END_TS=$(date +%s)
ELAPSED=$(( END_TS - START_TS ))

# ── JSON output ───────────────────────────────────────────────────────────────
if [[ "$OUTPUT_MODE" == "json" ]]; then
  echo "{"
  echo "  \"status\": $all_ok,"
  echo "  \"total\": $total,"
  echo "  \"healthy\": $healthy_count,"
  echo "  \"missing\": $missing,"
  echo "  \"unhealthy\": $unhealthy,"
  echo "  \"elapsed_seconds\": $ELAPSED,"
  echo "  \"containers\": ["
  idx=0
  for res in "${results[@]}"; do
    IFS='|' read -r name state health uptime restarts <<< "$res"
    echo "    {"
    echo "      \"name\": \"$name\","
    echo "      \"state\": \"$state\","
    echo "      \"health\": \"$health\","
    echo "      \"uptime\": \"$uptime\","
    echo "      \"restarts\": $restarts"
    idx=$(( idx + 1 ))
    [[ $idx -lt $total ]] && echo "    }," || echo "    }"
  done
  echo "  ]"
  echo "}"
  [[ $all_ok -eq 1 ]] && exit 0 || exit 1
fi

# ── Quiet output ──────────────────────────────────────────────────────────────
if [[ "$OUTPUT_MODE" == "quiet" ]]; then
  [[ $all_ok -eq 1 ]] && exit 0 || exit 1
fi

# ── Table output ──────────────────────────────────────────────────────────────

gap
# Table top border
table_div "╔" "╦" "╗" "═" "$X3"

# Column headers
printf "  ${X3}║${R}${BOLD}${GRAY}%-*s${R}${X3}║${R}${BOLD}${GRAY}%-*s${R}${X3}║${R}${BOLD}${GRAY}%-*s${R}${X3}║${R}${BOLD}${GRAY}%-*s${R}${X3}║${R}${BOLD}${GRAY}%-*s${R}${X3}║${R}\n" \
  "$C1" "  CONTAINER" \
  "$C2" "  STATUS" \
  "$C3" "  HEALTH" \
  "$C4" "  UPTIME" \
  "$C5" " RST"

# Header divider
table_div "╠" "╬" "╣" "═" "$X3"

# ── Rows ──────────────────────────────────────────────────────────────────────
row_count=0
for res in "${results[@]}"; do
  IFS='|' read -r container state health uptime restarts <<< "$res"

  # Status display
  case "$state" in
    running) status_str=" ${GREEN}● RUNNING${R}" ;;
    exited)  status_str=" ${RED}● EXITED${R}" ;;
    created) status_str=" ${YELLOW}● CREATED${R}" ;;
    missing) status_str=" ${GRAY}○ MISSING${R}" ;;
    *)       status_str=" ${ORANGE}● ${state^^}${R}" ;;
  esac

  # Health display
  case "$health" in
    healthy)   health_str=" ${GREEN}✔ healthy${R}" ;;
    unhealthy) health_str=" ${RED}✗ unhealthy${R}" ;;
    starting)  health_str=" ${YELLOW}⟳ starting${R}" ;;
    running)   health_str=" ${CYAN}◈ no-probe${R}" ;;
    none)      health_str=" ${GRAY}— n/a${R}" ;;
    *)         health_str=" ${GRAY}? ${health}${R}" ;;
  esac

  # Restart coloring
  if   [[ "$restarts" -gt 5 ]]; then rst_col="$RED"
  elif [[ "$restarts" -gt 0 ]]; then rst_col="$YELLOW"
  else rst_col="$GRAY"; fi

  # Container name coloring
  if   [[ "$state" == "missing"   ]]; then name_col="$GRAY"
  elif [[ "$health" == "healthy"  ]]; then name_col="$WHITE"
  elif [[ "$health" == "starting" ]]; then name_col="$YELLOW"
  else name_col="$RED"; fi

  container_str=" ${name_col}${container}${R}"
  uptime_str=" ${CYAN}${uptime}${R}"
  restart_str=" ${rst_col}${restarts}${R}"

  printf "  ${X3}║${R}%s${X3}║${R}%s${X3}║${R}%s${X3}║${R}%s${X3}║${R}%s${X3}║${R}\n" \
    "$(pad_visible_right "$container_str" "$C1")" \
    "$(pad_visible_right "$status_str" "$C2")" \
    "$(pad_visible_right "$health_str" "$C3")" \
    "$(pad_visible_right "$uptime_str" "$C4")" \
    "$(pad_visible_right "$restart_str" "$C5")"

  row_count=$(( row_count + 1 ))
  # Subtle row separator (not after last row)
  if [[ $row_count -lt $total ]]; then
    table_div "╠" "┼" "╣" "─" "$GRAY"
  fi
done

# Table bottom border
table_div "╚" "╩" "╝" "═" "$X3"

# ── Summary Panel ─────────────────────────────────────────────────────────────
gap
# Compute counts
warn_count=$(( total - healthy_count - missing - unhealthy ))
[ "$warn_count" -lt 0 ] && warn_count=0

INNER=$(( TABLE_W - 2 ))

printf "  ${X4}╔%s╗${R}\n" "$(repeat_char '═' $INNER)"

# Title
box_row_center_visible "${BOLD}${WHITE}◈  DIAGNOSTIC SUMMARY  ◈${R}" "$TABLE_W" "$X4"

printf "  ${X4}╠%s╣${R}\n" "$(repeat_char '═' $INNER)"

# Stats rows
PBAR_W=20

# Healthy
summary_row "✔" "HEALTHY" "$GREEN" "$healthy_count" "$total"

# Warnings
summary_row "⚠" "WARNINGS" "$YELLOW" "$warn_count" "$total"

# Critical / Missing
crit=$(( unhealthy + missing ))
summary_row "✗" "CRITICAL" "$RED" "$crit" "$total"

printf "  ${X4}╠%s╣${R}\n" "$(repeat_char '─' $INNER)"

# Elapsed time row
elapsed_str="  ${DIM}${GRAY}Scan completed in ${R}${LBLUE}${ELAPSED}s${R}${DIM}${GRAY}  ·  Checked ${total} containers${R}"
box_row_visible "$elapsed_str" "$TABLE_W" "$X4"

printf "  ${X4}╠%s╣${R}\n" "$(repeat_char '═' $INNER)"

# Final verdict
if [[ $all_ok -eq 1 ]]; then
  verdict_raw="✔   ALL SYSTEMS OPERATIONAL   ✔"
  box_row_center_visible "${BG_HEADER}${GREEN}${BOLD}${verdict_raw}${R}" "$TABLE_W" "$X4"
else
  verdict_raw="✗   SYSTEM INTEGRITY COMPROMISED   ✗"
  box_row_center_visible "${RED}${BOLD}${verdict_raw}${R}" "$TABLE_W" "$X4"
fi

printf "  ${X4}╚%s╝${R}\n" "$(repeat_char '═' $INNER)"

# ── Issues report ─────────────────────────────────────────────────────────────
if [[ ${#issues[@]} -gt 0 ]]; then
  gap
  printf "  ${RED}╔%s╗${R}\n" "$(repeat_char '═' $INNER)"
  box_row_center_visible "${BOLD}${YELLOW}⚠  ISSUES DETECTED  ⚠${R}" "$TABLE_W" "$RED"
  printf "  ${RED}╠%s╣${R}\n" "$(repeat_char '─' $INNER)"
  for issue in "${issues[@]}"; do
    issue_line="  ${YELLOW}⚠${R}  ${WHITE}${issue}${R}"
    box_row_visible "$issue_line" "$TABLE_W" "$RED"
  done
  printf "  ${RED}╠%s╣${R}\n" "$(repeat_char '─' $INNER)"
  box_row_center_visible "${DIM}${GRAY}Run: docker logs <container>  ·  docker inspect <container>${R}" "$TABLE_W" "$RED"
  printf "  ${RED}╚%s╝${R}\n" "$(repeat_char '═' $INNER)"
fi

gap2

# Glitch final status
if [[ $all_ok -eq 1 ]]; then
  glitch_text "SYSTEM INTEGRITY VERIFIED — ALL ${total} CONTAINERS NOMINAL" "$GREEN"
else
  glitch_text "WARNING: ${crit} CONTAINER(S) REQUIRE ATTENTION" "$RED"
fi

gap

[[ $all_ok -eq 1 ]] && exit 0 || exit 1
