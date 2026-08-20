#!/usr/bin/env bash
# Quick toggle for Cloudflare "Under Attack Mode" (emergency DDoS mitigation).
# Usage:
#   scripts/cloudflare-under-attack.sh on    # Enable (challenges all visitors)
#   scripts/cloudflare-under-attack.sh off   # Disable (back to normal)

set -euo pipefail

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ZONE_ID:-}" ]]; then
    echo "❌ Set CLOUDFLARE_API_TOKEN and CLOUDFLARE_ZONE_ID first."
    exit 1
fi

ACTION="${1:-status}"
case "$ACTION" in
    on)
        echo "🚨 Enabling Under Attack Mode..."
        LEVEL="under_attack"
        ;;
    off)
        echo "✅ Disabling Under Attack Mode (reverting to 'high')..."
        LEVEL="high"
        ;;
    *)
        CURRENT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/security_level" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result.value')
        echo "Current security level: $CURRENT"
        exit 0
        ;;
esac

curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/security_level" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"value\": \"$LEVEL\"}" | jq -r 'if .success then "✅ Done!" else "❌ Failed" end'
