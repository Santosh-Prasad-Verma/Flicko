#!/usr/bin/env bash
# =============================================================================
# Flicko — Azure CDN Cache Purge Utility
# =============================================================================
#
# Purge cached content from Azure CDN endpoint.
#
# Usage:
#   scripts/cdn-purge.sh all                    # Purge everything
#   scripts/cdn-purge.sh /avatars/user123.webp  # Purge specific path
#   scripts/cdn-purge.sh /audio/*               # Purge path pattern
#
# Prerequisites:
#   az login (authenticated Azure CLI)
#
# =============================================================================

set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
PROFILE_NAME="flicko-cdn-profile"
ENDPOINT_NAME="flicko-cdn"

if [[ -z "$RESOURCE_GROUP" ]]; then
    echo "❌ Set AZURE_RESOURCE_GROUP environment variable."
    echo "   export AZURE_RESOURCE_GROUP=your-resource-group"
    exit 1
fi

ACTION="${1:-help}"

case "$ACTION" in
    all)
        echo "🧹 Purging ALL CDN cached content..."
        az cdn endpoint purge \
            --resource-group "$RESOURCE_GROUP" \
            --profile-name "$PROFILE_NAME" \
            --name "$ENDPOINT_NAME" \
            --content-paths "/*"
        echo "✅ Full CDN purge initiated. Takes 2-5 minutes to propagate."
        ;;
    help|--help|-h)
        echo "Usage:"
        echo "  scripts/cdn-purge.sh all                    # Purge everything"
        echo "  scripts/cdn-purge.sh /avatars/user123.webp  # Purge specific file"
        echo "  scripts/cdn-purge.sh /audio/*               # Purge path pattern"
        echo ""
        echo "Environment:"
        echo "  AZURE_RESOURCE_GROUP  (required)"
        ;;
    *)
        echo "🧹 Purging CDN path: $ACTION"
        az cdn endpoint purge \
            --resource-group "$RESOURCE_GROUP" \
            --profile-name "$PROFILE_NAME" \
            --name "$ENDPOINT_NAME" \
            --content-paths "$ACTION"
        echo "✅ Purge initiated for: $ACTION"
        ;;
esac
