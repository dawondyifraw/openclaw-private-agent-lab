#!/usr/bin/env bash
# tests/test_tool_leakage.sh
# STRICT: must FAIL if tool/schema leakage markers appear in recent gateway logs.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"

PATTERN='<tools>|<toolbox>|function_call|sessions_send|HEALTH_CHECK_PING'

echo "Scanning gateway logs for leakage markers..."
if ! command -v journalctl >/dev/null 2>&1; then
  if [ "$MODE" = "strict" ]; then
    echo -e "${RED}FAIL${NC}: journalctl not available"
    exit 1
  fi
  echo -e "${YELLOW}SKIP${NC}: journalctl not available"
  exit 0
fi

LOGS="$(journalctl --user -u openclaw-gateway -n 800 --no-pager 2>/dev/null || true)"
if [ -z "$LOGS" ]; then
  if [ "$MODE" = "strict" ]; then
    echo -e "${RED}FAIL${NC}: no gateway logs found"
    exit 1
  fi
  echo -e "${YELLOW}SKIP${NC}: no gateway logs found"
  exit 0
fi

if echo "$LOGS" | rg -n "$PATTERN" >/tmp/openclaw_tool_leakage_hits.txt 2>/dev/null; then
  echo -e "${RED}FAIL${NC}: leakage markers found"
  sed -n '1,10p' /tmp/openclaw_tool_leakage_hits.txt || true
  exit 1
fi

echo -e "${GREEN}PASS${NC}: no leakage markers found in last 800 lines"

