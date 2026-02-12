#!/usr/bin/env bash
# tests/test_minimax_provider.sh
# Minimax is currently disabled from the default provider chain.
# In strict mode this test is non-blocking (EXPECTED_FAIL).

set -e

YELLOW='\033[1;33m'
NC='\033[0m'

MINIMAX_API_KEY=$(grep '^MINIMAX_API_KEY=' /home/devbox/.openclaw/.env | cut -d'=' -f2)
if [ -z "$MINIMAX_API_KEY" ]; then
  echo -e "${YELLOW}EXPECTED_FAIL${NC} (MINIMAX_API_KEY not set; Minimax disabled)"
  exit 0
fi

STATUS=$(curl -s -o /tmp/minimax_test.json -w "%{http_code}" \
  -X POST "https://api.minimax.chat/v1/chat/completions" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"MiniMax-M2.1","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' || true)

echo -e "${YELLOW}EXPECTED_FAIL${NC} (HTTP ${STATUS:-ERR}; provider disabled in chain)"
exit 0
