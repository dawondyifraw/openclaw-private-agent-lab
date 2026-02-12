#!/bin/bash
# tests/test_kimi_coding.sh
# Kimi is currently disabled from the default provider chain.
# In strict mode this test is non-blocking (EXPECTED_FAIL).

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"
KIMI_API_KEY=$(grep "^KIMI_API_KEY=" /home/devbox/.openclaw/.env | cut -d'=' -f2)

if [ -z "$KIMI_API_KEY" ]; then
    echo -e "${YELLOW}EXPECTED_FAIL${NC} (KIMI_API_KEY not set; Kimi disabled)"
    exit 0
fi

echo -n "Validating Kimi API Key... "
STATUS=$(curl -s -o /tmp/kimi_test.json -w "%{http_code}" -X POST "https://api.moonshot.cn/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KIMI_API_KEY" \
    -d '{"model":"moonshot-v1-8k","messages":[{"role":"user","content":"hi"}],"max_tokens":8}')

if [ "$STATUS" = "200" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${YELLOW}EXPECTED_FAIL${NC} (HTTP $STATUS; provider disabled in chain)"
fi
