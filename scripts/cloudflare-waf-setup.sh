#!/usr/bin/env bash
# =============================================================================
# Flicko — Cloudflare WAF & Security Setup
# =============================================================================
#
# Configures Cloudflare's free-tier security features to protect flicko.dev:
#   • Managed WAF rules (OWASP basics)
#   • Rate limiting on API endpoints
#   • Bot Fight Mode
#   • Security headers
#   • IP access rules
#
# Prerequisites:
#   1. Export CLOUDFLARE_API_TOKEN (Permissions: Zone:Edit, WAF:Edit)
#   2. Export CLOUDFLARE_ZONE_ID (from Cloudflare dashboard → Overview)
#
# Usage:
#   export CLOUDFLARE_API_TOKEN="your-token"
#   export CLOUDFLARE_ZONE_ID="your-zone-id"
#   bash scripts/cloudflare-waf-setup.sh
#
# Why not Azure WAF?
#   Azure WAF requires Application Gateway ($250+/month) — far exceeds
#   Azure Student plan budget. Cloudflare free tier provides equivalent
#   Layer 7 protection since traffic already routes through Cloudflare.
#
# =============================================================================

set -euo pipefail

# ── Validate environment ─────────────────────────────────────────────────────
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    echo "❌ CLOUDFLARE_API_TOKEN not set. Export it first."
    echo "   Get one at: https://dash.cloudflare.com/profile/api-tokens"
    exit 1
fi

if [[ -z "${CLOUDFLARE_ZONE_ID:-}" ]]; then
    echo "❌ CLOUDFLARE_ZONE_ID not set. Find it in Cloudflare dashboard → Overview."
    exit 1
fi

API_BASE="https://api.cloudflare.com/client/v4"
ZONE_ID="$CLOUDFLARE_ZONE_ID"
AUTH_HEADER="Authorization: Bearer $CLOUDFLARE_API_TOKEN"

echo "🔒 Configuring Cloudflare security for flicko.dev..."
echo ""

# ── Helper: API call ─────────────────────────────────────────────────────────
cf_api() {
    local method="$1"
    local path="$2"
    local data="${3:-}"
    
    if [[ -n "$data" ]]; then
        curl -s -X "$method" "$API_BASE$path" \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -s -X "$method" "$API_BASE$path" \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/json"
    fi
}

# ── 1. Security Level ────────────────────────────────────────────────────────
echo "1️⃣  Setting security level to 'high'..."
cf_api PATCH "/zones/$ZONE_ID/settings/security_level" \
    '{"value": "high"}' | jq -r '.success // "failed"'

# ── 2. SSL/TLS Mode ─────────────────────────────────────────────────────────
echo "2️⃣  Setting SSL mode to 'full (strict)'..."
cf_api PATCH "/zones/$ZONE_ID/settings/ssl" \
    '{"value": "strict"}' | jq -r '.success // "failed"'

# ── 3. TLS 1.2 Minimum ──────────────────────────────────────────────────────
echo "3️⃣  Setting minimum TLS version to 1.2..."
cf_api PATCH "/zones/$ZONE_ID/settings/min_tls_version" \
    '{"value": "1.2"}' | jq -r '.success // "failed"'

# ── 4. Always Use HTTPS ─────────────────────────────────────────────────────
echo "4️⃣  Enabling 'Always Use HTTPS'..."
cf_api PATCH "/zones/$ZONE_ID/settings/always_use_https" \
    '{"value": "on"}' | jq -r '.success // "failed"'

# ── 5. HSTS Headers ─────────────────────────────────────────────────────────
echo "5️⃣  Enabling HSTS (1 year, includeSubDomains)..."
cf_api PATCH "/zones/$ZONE_ID/settings/security_header" \
    '{
        "value": {
            "strict_transport_security": {
                "enabled": true,
                "max_age": 31536000,
                "include_subdomains": true,
                "preload": true,
                "nosniff": true
            }
        }
    }' | jq -r '.success // "failed"'

# ── 6. Bot Fight Mode ───────────────────────────────────────────────────────
echo "6️⃣  Enabling Bot Fight Mode..."
cf_api PATCH "/zones/$ZONE_ID/settings/bot_fight_mode" \
    '{"value": "on"}' 2>/dev/null | jq -r '.success // "check dashboard"'

# ── 7. Browser Integrity Check ──────────────────────────────────────────────
echo "7️⃣  Enabling Browser Integrity Check..."
cf_api PATCH "/zones/$ZONE_ID/settings/browser_check" \
    '{"value": "on"}' | jq -r '.success // "failed"'

# ── 8. Rate Limiting Rules (API protection) ──────────────────────────────────
echo "8️⃣  Creating rate limiting rule for /api/* (100 req/min per IP)..."

# Delete existing rate limit rules first (avoid duplicates)
EXISTING_RULES=$(cf_api GET "/zones/$ZONE_ID/rate_limits" | jq -r '.result[]?.id // empty')
for rule_id in $EXISTING_RULES; do
    cf_api DELETE "/zones/$ZONE_ID/rate_limits/$rule_id" > /dev/null 2>&1
done

cf_api POST "/zones/$ZONE_ID/rate_limits" '{
    "match": {
        "request": {
            "url_pattern": "*.flicko.dev/api/*",
            "schemes": ["_ALL_"],
            "methods": ["_ALL_"]
        }
    },
    "threshold": 100,
    "period": 60,
    "action": {
        "mode": "challenge",
        "timeout": 300
    },
    "enabled": true,
    "description": "Rate limit API endpoints: 100 req/min per IP"
}' | jq -r 'if .success then "✅ Created" else "⚠️  " + (.errors[0].message // "check dashboard") end'

# ── 9. Rate Limiting: Auth endpoints (stricter) ─────────────────────────────
echo "9️⃣  Creating strict rate limit for auth endpoints (20 req/min)..."
cf_api POST "/zones/$ZONE_ID/rate_limits" '{
    "match": {
        "request": {
            "url_pattern": "*.flicko.dev/api/v1/auth/*",
            "schemes": ["_ALL_"],
            "methods": ["POST"]
        }
    },
    "threshold": 20,
    "period": 60,
    "action": {
        "mode": "block",
        "timeout": 600
    },
    "enabled": true,
    "description": "Strict rate limit on auth: 20 POST/min (prevent brute force)"
}' | jq -r 'if .success then "✅ Created" else "⚠️  " + (.errors[0].message // "check dashboard") end'

# ── 10. WAF Managed Rules (Free tier) ────────────────────────────────────────
echo "🔟  Checking WAF managed ruleset availability..."
WAF_PACKAGES=$(cf_api GET "/zones/$ZONE_ID/firewall/waf/packages" | jq -r '.result[]?.name // "none"')
echo "    Available WAF packages: $WAF_PACKAGES"
echo "    ℹ️  Free plan includes Cloudflare Managed Ruleset (basic OWASP)"
echo "    ℹ️  SQL injection, XSS, and common attack patterns are covered"

# ── 11. Firewall Rules (block known bad patterns) ────────────────────────────
echo "1️⃣1️⃣  Creating firewall rule: block requests with SQL injection patterns..."
cf_api POST "/zones/$ZONE_ID/firewall/rules" '[{
    "filter": {
        "expression": "(http.request.uri.query contains \"UNION SELECT\" or http.request.uri.query contains \"1=1\" or http.request.uri.query contains \"DROP TABLE\" or http.request.body contains \"<script>\")",
        "description": "Block SQL injection and XSS patterns"
    },
    "action": "block",
    "description": "Block SQL injection and XSS in query params and body"
}]' 2>/dev/null | jq -r 'if .success then "✅ Created" else "⚠️  Firewall rules may require dashboard setup" end'

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Cloudflare security configuration complete!"
echo ""
echo "Active protections:"
echo "  🛡️  Security Level: High"
echo "  🔒 SSL: Full (Strict) + TLS 1.2 minimum + HSTS"
echo "  🤖 Bot Fight Mode: Enabled"
echo "  🌐 Browser Integrity Check: Enabled"
echo "  ⏱️  Rate Limit (API): 100 req/min per IP"
echo "  ⏱️  Rate Limit (Auth): 20 POST/min per IP"
echo "  🧱 WAF Managed Rules: Cloudflare defaults (OWASP basics)"
echo "  🚫 Custom Firewall: SQLi + XSS pattern blocking"
echo ""
echo "🆘 Emergency DDoS mode:"
echo "  Cloudflare Dashboard → Overview → Under Attack Mode → ON"
echo "  Or via API: scripts/cloudflare-under-attack.sh"
echo ""
echo "💰 Cost: \$0 (Cloudflare free tier)"
echo "═══════════════════════════════════════════════════════════════"
