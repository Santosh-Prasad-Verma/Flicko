#!/usr/bin/env bash
# =============================================================================
# Flicko — Azure Key Vault Secrets Sync Tool
# =============================================================================
#
# Syncs production environment variables between local .env.prod and
# Azure Key Vault (flicko-kv-2026).
#
# Prerequisites:
#   az login
#
# Usage:
#   scripts/azure-keyvault-sync.sh push   # Upload .env.prod -> Azure Key Vault
#   scripts/azure-keyvault-sync.sh pull   # Download Azure Key Vault -> .env.prod
#   scripts/azure-keyvault-sync.sh list   # List all secrets in Key Vault
#
# =============================================================================

set -euo pipefail

VAULT_NAME="flicko-kv-2026"
ENV_FILE="${1:-push}"

case "$ENV_FILE" in
    push)
        echo "🚀 Uploading secrets from .env.prod to Azure Key Vault ($VAULT_NAME)..."
        if [[ ! -f ".env.prod" ]]; then
            echo "❌ .env.prod not found!"
            exit 1
        fi

        while IFS='=' read -r key val || [[ -n "$key" ]]; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue

            # Clean key and value
            key=$(echo "$key" | xargs)
            val=$(echo "$val" | sed -e 's/^"//' -e 's/"$//')

            # Replace underscores with hyphens for Key Vault naming compliance
            kv_key=$(echo "$key" | tr '_' '-')

            if [[ -n "$val" ]]; then
                echo "  🔑 Storing secret: $kv_key..."
                az keyvault secret set --vault-name "$VAULT_NAME" --name "$kv_key" --value "$val" --output none
            fi
        done < .env.prod

        echo "✅ All secrets successfully uploaded to Azure Key Vault ($VAULT_NAME)!"
        ;;

    pull)
        echo "📥 Downloading secrets from Azure Key Vault ($VAULT_NAME) to .env.prod..."
        SECRETS=$(az keyvault secret list --vault-name "$VAULT_NAME" --query "[].name" -o tsv)

        echo "# Generated from Azure Key Vault ($VAULT_NAME)" > .env.prod.downloaded
        for kv_key in $SECRETS; do
            val=$(az keyvault secret show --vault-name "$VAULT_NAME" --name "$kv_key" --query "value" -o tsv)
            env_key=$(echo "$kv_key" | tr '-' '_')
            echo "${env_key}=\"${val}\"" >> .env.prod.downloaded
            echo "  ⬇️  Retrieved: $env_key"
        done

        mv .env.prod.downloaded .env.prod
        echo "✅ Secrets downloaded to .env.prod!"
        ;;

    list)
        echo "📋 Secrets in Azure Key Vault ($VAULT_NAME):"
        az keyvault secret list --vault-name "$VAULT_NAME" --query "[].{Name:name, Updated:attributes.updated}" -o table
        ;;

    audit)
        echo "🔍 Auditing Azure Key Vault ($VAULT_NAME) integrity..."
        MISSING=0
        REQUIRED_KEYS=("DATABASE-URL" "REDIS-URL" "JWT-SECRET" "AZURE-BLOB-CONNECTION-STRING" "AZURE-COMMUNICATION-CONNECTION-STRING" "LIVEKIT-API-KEY" "FLICKO-GEMINI-LIVE-MODEL")

        for key in "${REQUIRED_KEYS[@]}"; do
            if az keyvault secret show --vault-name "$VAULT_NAME" --name "$key" &> /dev/null; then
                echo "  ✅ Secret present: $key"
            else
                echo "  ❌ MISSING SECRET: $key"
                MISSING=$((MISSING + 1))
            fi
        done

        if [[ "$MISSING" -eq 0 ]]; then
            echo "🎉 All required production secrets are healthy in $VAULT_NAME!"
        else
            echo "⚠️ Found $MISSING missing required secret(s) in $VAULT_NAME!"
            exit 1
        fi
        ;;

    *)
        echo "Usage: $0 [push|pull|list|audit]"
        exit 1
        ;;
esac
