#!/usr/bin/env bash
# STRICT: ensure auth profiles are propagated to all runtime agents and include a safe local Ollama profile.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"
ROOT="/home/devbox/.openclaw"

if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only auth propagation test"
  exit 0
fi

bash "$ROOT/scripts/sync_auth_profiles.sh" --copy >/dev/null

AGENTS=(main anxietychat assistant g-coder g-hello g-moltd merry-bot)
MAIN_AUTH="$ROOT/agents/main/agent/auth-profiles.json"

if [ ! -f "$MAIN_AUTH" ]; then
  echo -e "${RED}FAIL${NC}: missing main auth file: $MAIN_AUTH"
  exit 1
fi

main_hash="$(sha256sum "$MAIN_AUTH" | awk '{print $1}')"
echo "main auth hash: ${main_hash:0:10}"

for agent in "${AGENTS[@]}"; do
  f="$ROOT/agents/$agent/agent/auth-profiles.json"
  echo -n "checking $agent auth... "
  if [ ! -f "$f" ]; then
    echo -e "${RED}FAIL${NC} (missing $f)"
    exit 1
  fi

  # Must expose local ollama default profile; key may be omitted or set to static 'ollama'.
  if ! jq -e '.profiles["ollama:default"].provider == "ollama"' "$f" >/dev/null 2>&1; then
    echo -e "${RED}FAIL${NC} (ollama:default missing/invalid)"
    exit 1
  fi

  # Ensure runtime mapping exists so provider switch/fallback can resolve a profile.
  if ! jq -e '.lastGood.ollama == "ollama:default"' "$f" >/dev/null 2>&1; then
    echo -e "${RED}FAIL${NC} (lastGood.ollama mapping missing)"
    exit 1
  fi

  ahash="$(sha256sum "$f" | awk '{print $1}')"
  if [ "$ahash" != "$main_hash" ]; then
    echo -e "${RED}FAIL${NC} (content drift from main auth)"
    exit 1
  fi

  echo -e "${GREEN}PASS${NC}"
done

echo -e "${GREEN}PASS${NC}: provider auth propagation is consistent across agents"
