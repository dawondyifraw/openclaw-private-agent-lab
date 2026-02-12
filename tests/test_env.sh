#!/bin/bash
# tests/test_env.sh
# Verifies required environment variables and secrets permissions.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Checking environment variables..."
ENV_FILE="/home/devbox/.openclaw/.env"

MODE="${OPENCLAW_TEST_MODE:-default}"
MISSING_ANY=0

# STRICT should reflect real provider requirements:
# - Required: OpenRouter + Groq (these must be working).
# - Optional: Google (Gemini direct), Kimi, Minimax.
if [ "$MODE" = "strict" ]; then
    REQUIRED_VARS=("OPENROUTER_API_KEY" "GROQ_API_KEY" "OPENCLAW_GATEWAY_TOKEN")
else
    REQUIRED_VARS=("GOOGLE_API_KEY" "GROQ_API_KEY" "OPENROUTER_API_KEY" "KIMI_API_KEY")
fi

for var in "${REQUIRED_VARS[@]}"; do
    echo -n "  $var: "
    if grep -q "^$var=" "$ENV_FILE"; then
        echo -e "${GREEN}EXISTS${NC}"
    else
        echo -e "${RED}MISSING${NC} in .env"
        MISSING_ANY=1
        # Since we are running in a shell that might not have them exported yet,
        # we check the .env file.
    fi
done

echo "Checking sandbox auth tokens in .env..."
SANDBOX_VARS=("SANDBOX_GUARD_TOKEN" "TOOL_RUNNER_TOKEN")
for var in "${SANDBOX_VARS[@]}"; do
    echo -n "  $var: "
    if grep -q "^$var=" "$ENV_FILE"; then
        echo -e "${GREEN}EXISTS${NC}"
    else
        echo -e "${RED}MISSING${NC} in .env"
        MISSING_ANY=1
    fi
done

echo -n "Checking secrets directory permissions... "
SECRETS_DIR="/home/devbox/.openclaw/secrets"
if [ -d "$SECRETS_DIR" ]; then
    PERMS=$(stat -c "%a" "$SECRETS_DIR")
    if [ "$PERMS" == "700" ] || [ "$PERMS" == "600" ]; then
        echo -e "${GREEN}PASS ($PERMS)${NC}"
    else
        echo -e "${RED}FAIL ($PERMS)${NC}"
        echo "Warning: Secrets directory should be 700 or 600."
        if [ "$MODE" = "strict" ]; then
            exit 1
        fi
    fi
else
    if [ "$MODE" = "strict" ]; then
        echo -e "${RED}FAIL (Not found)${NC}"
        exit 1
    fi
    echo -e "${YELLOW}SKIP (Not found)${NC}"
fi

if [ "$MODE" = "strict" ] && [ "$MISSING_ANY" -ne 0 ]; then
    echo "STRICT MODE: missing required .env variables."
    exit 1
fi
