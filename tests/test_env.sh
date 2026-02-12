#!/bin/bash
# tests/test_env.sh
# Verifies required environment variables and secrets permissions.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Checking environment variables..."
REQUIRED_VARS=("GOOGLE_API_KEY" "GROQ_API_KEY" "OPENROUTER_API_KEY" "KIMI_API_KEY")
ENV_FILE="/home/devbox/.openclaw/.env"

for var in "${REQUIRED_VARS[@]}"; do
    echo -n "  $var: "
    if grep -q "^$var=" "$ENV_FILE"; then
        echo -e "${GREEN}EXISTS${NC}"
    else
        echo -e "${RED}MISSING${NC} in .env"
        # Since we are running in a shell that might not have them exported yet,
        # we check the .env file.
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
    fi
else
    echo -e "SKIP (Not found)"
fi
