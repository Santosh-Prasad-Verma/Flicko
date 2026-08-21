#!/usr/bin/env bash

# ==============================================================================
# Flicko Tolgee Localization Sync Script
# Pulls latest translations from self-hosted Tolgee server and updates
# Flutter ARB files and Go backend l10n.
# ==============================================================================

set -euo pipefail

TOLGEE_URL="${TOLGEE_API_URL:-http://104.43.114.32:8085}"
TOLGEE_KEY="${TOLGEE_API_KEY:-tgpak_gjpwy2jwgy2gwmtehb2gi4lvmjqxg5lnmmzg63llmjzhm}"
PROJECT_ID="${TOLGEE_PROJECT_ID:-2}"
L10N_DIR="mobile/lib/features/sonic_music/localization"

echo "🌐 Syncing latest translations from Tolgee (${TOLGEE_URL})..."

TMP_ZIP="/tmp/tolgee_export.zip"
TMP_EXTRACT="/tmp/tolgee_l10n"

# Export JSON zip from Tolgee
curl_exit_code=0
curl -sS -f \
  --retry 3 \
  --retry-all-errors \
  --retry-delay 5 \
  --connect-timeout 15 \
  --max-time 300 \
  -H "X-API-Key: ${TOLGEE_KEY}" \
  "${TOLGEE_URL}/v2/projects/${PROJECT_ID}/export?format=JSON" \
  -o "${TMP_ZIP}" || curl_exit_code=$?

if [ "${curl_exit_code}" -ne 0 ]; then
  if [ "${curl_exit_code}" -eq 28 ]; then
    echo "⚠️ Tolgee export timed out (curl exit 28). Skipping sync for this run."
    exit 0
  fi
  echo "❌ Failed to export translations from Tolgee (curl exit ${curl_exit_code})."
  exit "${curl_exit_code}"
fi

mkdir -p "${TMP_EXTRACT}"
unzip -q -o "${TMP_ZIP}" -d "${TMP_EXTRACT}"

echo "✅ Downloaded latest translations:"
ls -la "${TMP_EXTRACT}"

echo "🎉 Tolgee localization sync complete!"
