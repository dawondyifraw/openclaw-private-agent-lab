#!/bin/bash
# tests/test_google_provider.sh
# Verifies Google API key validity using the models list endpoint.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -n "Validating Google API Key... "
ENV_FILE="/home/devbox/.openclaw/.env"
GOOGLE_API_KEY=$(grep "^GOOGLE_API_KEY=" "$ENV_FILE" | cut -d '=' -f2)

if [ -z "$GOOGLE_API_KEY" ]; then
    echo -e "${RED}FAIL (Key not found in .env)${NC}"
    exit 1
fi

STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://generativelanguage.googleapis.com/v1beta/models?key=${GOOGLE_API_KEY}")

if [ "$STATUS_CODE" == "200" ]; then
    echo -e "${GREEN}VALID${NC}"
else
    echo -e "${RED}INVALID (HTTP $STATUS_CODE)${NC}"
    echo "Error: Google API Key rejected. Please check project restrictions and rotation."
    exit 1
fi
