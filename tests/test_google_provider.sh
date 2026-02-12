#!/bin/bash
# tests/test_google_provider.sh
# Verifies Google API key validity using the models list endpoint.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -n "Validating Google API Key... "
ENV_FILE="/home/devbox/.openclaw/.env"
GOOGLE_API_KEY=$(grep "^GOOGLE_API_KEY=" "$ENV_FILE" | cut -d '=' -f2)

if [ -z "$GOOGLE_API_KEY" ]; then
    if [ "${OPENCLAW_TEST_MODE:-default}" = "strict" ]; then
        echo -e "${RED}FAIL${NC} (Key not found in .env; Gemini is required for strict)"
        exit 1
    fi
    echo -e "${YELLOW}SKIP${NC} (Key not found in .env)"
    exit 0
fi

STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://generativelanguage.googleapis.com/v1beta/models?key=${GOOGLE_API_KEY}")

if [ "$STATUS_CODE" == "200" ]; then
    echo -e "${GREEN}VALID${NC}"
else
    if [ "${OPENCLAW_TEST_MODE:-default}" = "strict" ]; then
        echo -e "${RED}FAIL${NC} (HTTP $STATUS_CODE; Gemini is required for strict)"
        exit 1
    fi
    echo -e "${YELLOW}WARN (HTTP $STATUS_CODE)${NC}"
    echo "Note: Google API key validation failed; not failing in default mode."
    exit 0
fi
