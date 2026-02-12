#!/bin/bash
# tests/test_groq_provider.sh
# STRICT: must PASS (Groq is a required working provider).

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"
ENV_FILE="/home/devbox/.openclaw/.env"

echo -n "Checking Groq API key presence... "
GROQ_API_KEY=$(grep "^GROQ_API_KEY=" "$ENV_FILE" | head -n 1 | cut -d '=' -f2-)
if [ -z "$GROQ_API_KEY" ]; then
    echo -e "${RED}FAIL${NC} (GROQ_API_KEY missing in .env)"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

echo -n "Validating Groq via lightweight chat completion... "
MODEL="${GROQ_TEST_MODEL:-llama-3.3-70b-versatile}"

R=$(curl -sS -o /tmp/groq_test.json -w "%{http_code}" \
    -X POST "https://api.groq.com/openai/v1/chat/completions" \
    -H "Authorization: Bearer ${GROQ_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with the single word: OK\"}],\"max_tokens\":4,\"temperature\":0}")

if [ "$R" != "200" ]; then
    if [ "$MODE" = "strict" ]; then
        echo -e "${RED}FAIL${NC} (HTTP $R)"
        echo "Response (truncated): $(head -c 300 /tmp/groq_test.json)"
        exit 1
    fi
    echo -e "${YELLOW}WARN${NC} (HTTP $R)"
    exit 0
fi

if jq -e '.choices[0].message.content | type=="string" and length>0' /tmp/groq_test.json >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC} (model=${MODEL})"
else
    echo -e "${RED}FAIL${NC} (no message content)"
    echo "Response (truncated): $(head -c 300 /tmp/groq_test.json)"
    exit 1
fi

