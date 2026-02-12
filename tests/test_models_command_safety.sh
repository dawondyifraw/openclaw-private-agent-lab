#!/usr/bin/env bash
# STRICT: config-level guard for /models switching safety.
# Providers exposed by models.json must have runtime auth mappings, otherwise /models can switch into a broken state.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"
if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only /models safety test"
  exit 0
fi

ROOT="/home/devbox/.openclaw"
MODELS="$ROOT/agents/main/agent/models.json"
AUTH="$ROOT/agents/main/agent/auth-profiles.json"

if [ ! -f "$MODELS" ]; then
  echo -e "${RED}FAIL${NC}: missing $MODELS"
  exit 1
fi
if [ ! -f "$AUTH" ]; then
  echo -e "${RED}FAIL${NC}: missing $AUTH"
  exit 1
fi

# Required switchable providers for this deployment.
required=(google openrouter groq ollama)
for p in "${required[@]}"; do
  echo -n "provider $p in models + auth mapping... "
  if ! jq -e --arg p "$p" '.providers[$p] != null' "$MODELS" >/dev/null 2>&1; then
    echo -e "${RED}FAIL${NC} (missing in models.json)"
    exit 1
  fi
  if ! jq -e --arg p "$p" '.lastGood[$p] != null' "$AUTH" >/dev/null 2>&1; then
    echo -e "${RED}FAIL${NC} (missing in auth lastGood)"
    exit 1
  fi
  echo -e "${GREEN}PASS${NC}"
done

echo -n "ollama local profile safety... "
if ! jq -e '.profiles["ollama:default"].provider == "ollama"' "$AUTH" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}"
  exit 1
fi
if ! jq -e '.profiles["ollama:default"].type == "api_key" or .profiles["ollama:default"].type == "none"' "$AUTH" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}"
  exit 1
fi
echo -e "${GREEN}PASS${NC}"

echo "PASS: /models should refuse unsafe switch targets when auth mapping is absent; current config is safe."
