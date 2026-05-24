#!/usr/bin/env bash

# Exit on error
set -e

# Sentry release management script for Flicko (Flutter Mobile App)
# Reference: https://docs.sentry.io/product/cli/releases/

# Configuration values
SENTRY_ORG="${SENTRY_ORG:-flicko-iq}"
SENTRY_PROJECT="${SENTRY_PROJECT:-flutter}"

# Color codes for pretty console logs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Starting Sentry Release Automation ===${NC}"

# 1. Verify sentry-cli is installed
if ! command -v sentry-cli &> /dev/null; then
    echo -e "${YELLOW}sentry-cli is not found on your global PATH. Trying local path...${NC}"
    if [ -f "$HOME/.local/bin/sentry" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo -e "${RED}Error: sentry-cli is not installed. Run 'curl -sL https://cli.sentry.dev/install -fsS | bash' first.${NC}"
        exit 1
    fi
fi

# 2. Verify Sentry Authentication Token is set
if [ -z "$SENTRY_AUTH_TOKEN" ]; then
    # Try reading from mobile/.env if available
    if [ -f ".env" ]; then
        echo -e "${BLUE}Reading SENTRY_AUTH_TOKEN from .env file...${NC}"
        # Parse token from .env
        ENV_TOKEN=$(grep -E "^SENTRY_AUTH_TOKEN=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [ -n "$ENV_TOKEN" ]; then
            export SENTRY_AUTH_TOKEN="$ENV_TOKEN"
        fi
    fi
fi

if [ -z "$SENTRY_AUTH_TOKEN" ]; then
    echo -e "${RED}Error: SENTRY_AUTH_TOKEN is not set.${NC}"
    echo -e "${YELLOW}Please set it in your environment: export SENTRY_AUTH_TOKEN=\"your-token\"${NC}"
    exit 1
fi

export SENTRY_ORG
export SENTRY_PROJECT

# 3. Propose a new release version
echo -e "${BLUE}Proposing release version...${NC}"
VERSION=$(sentry-cli releases propose-version)
echo -e "${GREEN}Proposed Version: $VERSION${NC}"

# 4. Create the new Sentry Release
echo -e "${BLUE}Creating Sentry release: $VERSION...${NC}"
sentry-cli releases new "$VERSION"

# 5. Bind commits to the Sentry Release
echo -e "${BLUE}Associating git commits with release...${NC}"
sentry-cli releases set-commits "$VERSION" --auto || {
    echo -e "${YELLOW}Warning: Could not automatically associate commits. Ensure you have git history initialized.${NC}"
}

# 6. Upload Flutter Debug Symbols & Sourcemaps (If release build directories exist)
echo -e "${BLUE}Uploading Flutter symbols and source maps...${NC}"
if [ -d "build/app/outputs/symbols" ] || [ -d "build/app/intermediates/flutter/release" ]; then
    echo -e "${GREEN}Uploading Android debug symbols...${NC}"
    sentry-cli flutter symbols upload || echo -e "${YELLOW}Skipped automatic Android symbols upload.${NC}"
fi

# 7. Finalize Sentry Release
echo -e "${BLUE}Finalizing Sentry release...${NC}"
sentry-cli releases finalize "$VERSION"

echo -e "${GREEN}=== Sentry Release $VERSION finalized successfully! ===${NC}"
