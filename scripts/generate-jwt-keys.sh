#!/usr/bin/env bash
# scripts/generate-jwt-keys.sh
#
# Generates an Ed25519 key pair for JWT signing/verification.
# Output:
#   secrets/jwt_private.pem  — PKCS8 private key (mode 600)
#   secrets/jwt_public.pem   — PKIX public key   (mode 600)
#
# Usage:
#   ./scripts/generate-jwt-keys.sh
#   ./scripts/generate-jwt-keys.sh --force   # overwrite existing keys
#
# Requirements: openssl >= 1.1.1 (Ed25519 support)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$ROOT_DIR/secrets"

PRIVATE_KEY="$SECRETS_DIR/jwt_private.pem"
PUBLIC_KEY="$SECRETS_DIR/jwt_public.pem"

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

# Check for existing keys.
if [[ -f "$PRIVATE_KEY" || -f "$PUBLIC_KEY" ]] && [[ "$FORCE" != true ]]; then
    echo "Error: Key files already exist:"
    [[ -f "$PRIVATE_KEY" ]] && echo "  $PRIVATE_KEY"
    [[ -f "$PUBLIC_KEY" ]]  && echo "  $PUBLIC_KEY"
    echo ""
    echo "Use --force to overwrite."
    exit 1
fi

# Check openssl availability.
if ! command -v openssl &>/dev/null; then
    echo "Error: openssl is not installed or not in PATH."
    exit 1
fi

# Verify Ed25519 support.
if ! openssl list -public-key-algorithms | grep -qi ed25519; then
    # Fallback check
    if ! openssl genpkey -algorithm Ed25519 -text 2>&1 | grep -qi "Algorithm"; then
    echo "Error: openssl does not support Ed25519. Requires >= 1.1.1."
    echo "Installed version: $(openssl version)"
    exit 1
fi

# Create secrets directory.
mkdir -p "$SECRETS_DIR"

echo "Generating Ed25519 key pair..."

# Generate private key (PKCS8 PEM).
openssl genpkey -algorithm Ed25519 -out "$PRIVATE_KEY"

# Extract public key (PKIX PEM).
openssl pkey -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY"

# Lock down permissions.
chmod 600 "$PRIVATE_KEY"
chmod 600 "$PUBLIC_KEY"

echo ""
echo "Keys generated successfully:"
echo "  Private: $PRIVATE_KEY  (mode 600)"
echo "  Public:  $PUBLIC_KEY   (mode 600)"
echo ""
echo "Add 'secrets/' to .gitignore if not already present."

# Ensure secrets/ is in .gitignore.
GITIGNORE="$ROOT_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -q '^secrets/' "$GITIGNORE"; then
        echo "secrets/" >> "$GITIGNORE"
        echo "Added 'secrets/' to .gitignore"
    fi
else
    echo "secrets/" > "$GITIGNORE"
    echo "Created .gitignore with 'secrets/' entry"
fi
