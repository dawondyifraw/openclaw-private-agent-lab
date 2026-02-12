#!/usr/bin/env bash
# tests/test_models_provider_guard.sh
# STRICT: Kimi/Minimax must be disabled from switchable provider lists.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"
ROOT="/home/devbox/.openclaw"

if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only models provider guard"
  exit 0
fi

files=(
  "$ROOT/agents/main/agent/models.json"
  "$ROOT/agents/g-coder/agent/models.json"
  "$ROOT/agents/g-hello/agent/models.json"
  "$ROOT/agents/anxietychat/agent/models.json"
  "$ROOT/agents/merry-bot/agent/models.json"
  "$ROOT/agents/assistant/agent/models.json"
)

for f in "${files[@]}"; do
  echo -n "checking disabled providers in $(basename "$(dirname "$f")")/models.json... "
  if jq -e '.providers["kimi-coding"] != null or .providers["minimax"] != null' "$f" >/dev/null 2>&1; then
    echo -e "${RED}FAIL${NC}"
    exit 1
  fi
  echo -e "${GREEN}PASS${NC}"
done

echo "PASS: disabled providers are removed from /model(s) selectable provider configs."
echo "Expected runtime response for disabled targets: Provider not configured/disabled. Available: Gemini, OpenRouter, Groq, Ollama."
