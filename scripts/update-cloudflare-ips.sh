#!/usr/bin/env bash
# =============================================================================
# Flicko — Cloudflare IP Range UFW Updater
# =============================================================================
#
# Fetches the latest Cloudflare IP ranges from their public API and updates
# UFW firewall rules to allow HTTP/HTTPS traffic only from Cloudflare.
#
# Why this is needed:
#   Cloudflare occasionally adds or removes IP ranges. If we don't update,
#   legitimate traffic from new ranges gets blocked (downtime), or old
#   ranges that are no longer Cloudflare could be spoofed.
#
# How it works:
#   1. Fetches IPv4 and IPv6 ranges from https://api.cloudflare.com/client/v4/ips
#   2. Snapshots current CF-related UFW rules
#   3. Removes all old Cloudflare HTTP/HTTPS rules
#   4. Adds new rules for each IP range
#   5. Logs the diff for audit
#
# Installation (one-time):
#   sudo cp scripts/update-cloudflare-ips.sh /usr/local/bin/update-cloudflare-ips.sh
#   sudo chmod +x /usr/local/bin/update-cloudflare-ips.sh
#
# Cron setup (weekly, Sunday 3 AM UTC):
#   echo '0 3 * * 0 root /usr/local/bin/update-cloudflare-ips.sh' | \
#       sudo tee /etc/cron.d/cloudflare-ips
#
# Manual run:
#   sudo bash scripts/update-cloudflare-ips.sh
#
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Cloudflare API endpoint for IP ranges.
CF_API_URL="https://api.cloudflare.com/client/v4/ips"

# Fallback plain-text endpoints (used if JSON API fails).
CF_IPV4_URL="https://www.cloudflare.com/ips-v4"
CF_IPV6_URL="https://www.cloudflare.com/ips-v6"

# Local cache of known-good Cloudflare IPs (fallback if API is down).
CF_CACHE_DIR="/var/cache/flicko"
CF_CACHE_FILE="${CF_CACHE_DIR}/cloudflare-ips.txt"

# Log file for audit trail.
LOG_FILE="/var/log/flicko-cloudflare-update.log"

# UFW comment prefix — used to identify rules managed by this script.
# Must match exactly what server-setup.sh uses.
UFW_COMMENT_PREFIX="Cloudflare"

# ─────────────────────────────────────────────────────────────────────────────
# Functions
# ─────────────────────────────────────────────────────────────────────────────

log() {
    local msg="[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"
    echo "$msg"
    echo "$msg" >> "${LOG_FILE}"
}

die() {
    log "ERROR: $*"
    exit 1
}

# Fetch Cloudflare IPs from the JSON API.
# Returns one CIDR range per line.
fetch_cf_ips_json() {
    local response
    response=$(curl -sf --max-time 30 "${CF_API_URL}") || return 1

    # Validate JSON structure: must have .result.ipv4_cidrs and .result.ipv6_cidrs
    if ! echo "${response}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data.get('success', False), 'API returned success=false'
ipv4 = data['result']['ipv4_cidrs']
ipv6 = data['result']['ipv6_cidrs']
assert len(ipv4) > 5, f'Too few IPv4 ranges: {len(ipv4)}'
for cidr in ipv4 + ipv6:
    print(cidr)
" 2>/dev/null; then
        return 1
    fi
}

# Fetch Cloudflare IPs from the plain-text fallback endpoints.
fetch_cf_ips_text() {
    local ipv4 ipv6
    ipv4=$(curl -sf --max-time 30 "${CF_IPV4_URL}") || return 1
    ipv6=$(curl -sf --max-time 30 "${CF_IPV6_URL}") || return 1

    # Sanity check: must have at least 5 IPv4 ranges.
    local count
    count=$(echo "${ipv4}" | wc -l)
    if [[ ${count} -lt 5 ]]; then
        return 1
    fi

    echo "${ipv4}"
    echo "${ipv6}"
}

# Fetch from cache (last known good).
fetch_cf_ips_cache() {
    if [[ -f "${CF_CACHE_FILE}" ]]; then
        cat "${CF_CACHE_FILE}"
    else
        return 1
    fi
}

# Get the current UFW rule numbers for Cloudflare rules (in reverse order
# so we can delete from highest to lowest without index shifting).
get_cf_rule_numbers() {
    ufw status numbered 2>/dev/null | \
        grep -i "${UFW_COMMENT_PREFIX}" | \
        grep -oP '^\[\s*\K[0-9]+' | \
        sort -rn
}

# ─────────────────────────────────────────────────────────────────────────────
# Preflight
# ─────────────────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root."
fi

if ! command -v ufw &>/dev/null; then
    die "UFW is not installed."
fi

if ! command -v curl &>/dev/null; then
    die "curl is not installed."
fi

mkdir -p "${CF_CACHE_DIR}"
touch "${LOG_FILE}"

log "=========================================="
log "Cloudflare IP update started"
log "=========================================="

# ─────────────────────────────────────────────────────────────────────────────
# Fetch latest Cloudflare IPs
# ─────────────────────────────────────────────────────────────────────────────

CF_IPS=""

# Try JSON API first, then plain-text fallback, then cache.
log "Fetching Cloudflare IPs from JSON API..."
if CF_IPS=$(fetch_cf_ips_json); then
    log "  ✓ Fetched from JSON API"
else
    log "  ✗ JSON API failed, trying plain-text endpoints..."
    if CF_IPS=$(fetch_cf_ips_text); then
        log "  ✓ Fetched from plain-text endpoints"
    else
        log "  ✗ Plain-text failed, falling back to cache..."
        if CF_IPS=$(fetch_cf_ips_cache); then
            log "  ⚠ Using cached IPs (may be stale)"
        else
            die "All sources failed and no cache exists. Aborting to avoid lockout."
        fi
    fi
fi

# Filter out empty lines and comments, deduplicate.
CF_IPS=$(echo "${CF_IPS}" | grep -v '^$' | grep -v '^#' | sort -u)

IP_COUNT=$(echo "${CF_IPS}" | wc -l)
log "  Total IP ranges: ${IP_COUNT}"

if [[ ${IP_COUNT} -lt 5 ]]; then
    die "Suspiciously few IP ranges (${IP_COUNT}). Aborting to prevent lockout."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Compare with cache — skip if unchanged
# ─────────────────────────────────────────────────────────────────────────────

if [[ -f "${CF_CACHE_FILE}" ]]; then
    CACHED_IPS=$(sort -u "${CF_CACHE_FILE}")
    if [[ "${CF_IPS}" == "${CACHED_IPS}" ]]; then
        log "  No changes detected. Skipping UFW update."
        log "=========================================="
        exit 0
    fi
    log "  Changes detected — updating UFW rules."
else
    log "  No cache found — full rule refresh."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Remove old Cloudflare UFW rules
# ─────────────────────────────────────────────────────────────────────────────
# Rules are deleted by number in reverse order (highest first) to avoid
# index shifting as rules are removed.

log "Removing old Cloudflare UFW rules..."

OLD_RULES=$(get_cf_rule_numbers || true)
OLD_COUNT=0

if [[ -n "${OLD_RULES}" ]]; then
    for rule_num in ${OLD_RULES}; do
        ufw --force delete "${rule_num}" > /dev/null 2>&1 || true
        OLD_COUNT=$((OLD_COUNT + 1))
    done
fi

log "  Removed ${OLD_COUNT} old rules."

# ─────────────────────────────────────────────────────────────────────────────
# Add new Cloudflare UFW rules
# ─────────────────────────────────────────────────────────────────────────────

log "Adding new Cloudflare UFW rules..."

NEW_COUNT=0

while IFS= read -r cidr; do
    [[ -z "${cidr}" ]] && continue

    # Determine comment suffix based on IP version.
    if [[ "${cidr}" == *:* ]]; then
        COMMENT="${UFW_COMMENT_PREFIX} HTTPS v6"
    else
        COMMENT="${UFW_COMMENT_PREFIX} HTTPS"
    fi

    ufw allow from "${cidr}" to any port 80 proto tcp comment "${UFW_COMMENT_PREFIX} HTTP" > /dev/null 2>&1
    ufw allow from "${cidr}" to any port 443 proto tcp comment "${COMMENT}" > /dev/null 2>&1
    NEW_COUNT=$((NEW_COUNT + 2))
done <<< "${CF_IPS}"

log "  Added ${NEW_COUNT} new rules (${IP_COUNT} ranges × 2 ports)."

# ─────────────────────────────────────────────────────────────────────────────
# Update cache
# ─────────────────────────────────────────────────────────────────────────────

echo "${CF_IPS}" > "${CF_CACHE_FILE}"
log "  Cache updated: ${CF_CACHE_FILE}"

# ─────────────────────────────────────────────────────────────────────────────
# Verify
# ─────────────────────────────────────────────────────────────────────────────

FINAL_COUNT=$(ufw status numbered 2>/dev/null | grep -ci "${UFW_COMMENT_PREFIX}" || true)
log "  Verification: ${FINAL_COUNT} Cloudflare rules active in UFW."

log "=========================================="
log "Cloudflare IP update complete"
log "=========================================="
