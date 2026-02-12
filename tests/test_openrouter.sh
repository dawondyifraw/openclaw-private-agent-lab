#!/bin/bash
# tests/test_openrouter.sh
# Verifies OpenRouter connectivity and model availability.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -n "Checking OpenRouter connectivity... "
ENV_FILE="/home/devbox/.openclaw/.env"
OPENROUTER_API_KEY=$(grep "^OPENROUTER_API_KEY=" "$ENV_FILE" | cut -d '=' -f2)

if [ -z "$OPENROUTER_API_KEY" ]; then
    echo -e "${RED}FAIL (Key not found in .env)${NC}"
    exit 1
fi

RESPONSE=$(curl -s -X GET "https://openrouter.ai/api/v1/models" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}")

if ! echo "$RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
    echo -e "${RED}FAIL (Invalid response)${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi
echo -e "${GREEN}PASS${NC}"

DESIRED_MODEL="cognitivecomputations/dolphin-mixtral-8x22b"
echo -n "Checking for $DESIRED_MODEL... "

if echo "$RESPONSE" | jq -r '.data[].id' | grep -q "^$DESIRED_MODEL$"; then
    echo -e "${GREEN}AVAILABLE${NC}"
else
    echo -e "${RED}UNAVAILABLE${NC}"
    echo "Detecting fallback models..."
    # Recommend a fallback from available models
    FALLBACK=$(echo "$RESPONSE" | jq -r '.data | sort_by(.id) | .[0].id')
    echo "Recommended fallback: $FALLBACK"
    
    # Write to recommended_models.md as per request
    cat <<EOF > /home/devbox/.openclaw/docs/recommended_models.md
# Recommended OpenRouter Models
Date: $(date)

The desired model \`$DESIRED_MODEL\` was not found.
Available alternatives:
- $FALLBACK
- $(echo "$RESPONSE" | jq -r '.data[].id' | head -n 5 | paste -sd ", " -)
EOF
fi
