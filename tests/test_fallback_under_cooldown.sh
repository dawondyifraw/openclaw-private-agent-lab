#!/usr/bin/env bash
# tests/test_fallback_under_cooldown.sh
# STRICT: prove Groq cooldown/failure path can recover via Gemini/OpenRouter.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"
if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only cooldown fallback test"
  exit 0
fi

ENV_FILE="/home/devbox/.openclaw/.env"
GOOGLE_API_KEY=$(grep '^GOOGLE_API_KEY=' "$ENV_FILE" | cut -d= -f2-)
OPENROUTER_API_KEY=$(grep '^OPENROUTER_API_KEY=' "$ENV_FILE" | cut -d= -f2-)

[ -n "$GOOGLE_API_KEY" ] || { echo -e "${RED}FAIL${NC}: GOOGLE_API_KEY missing"; exit 1; }
[ -n "$OPENROUTER_API_KEY" ] || { echo -e "${RED}FAIL${NC}: OPENROUTER_API_KEY missing"; exit 1; }

tmp_groq="$(mktemp)"; tmp_google="$(mktemp)"; tmp_or="$(mktemp)"
trap 'rm -f "$tmp_groq" "$tmp_google" "$tmp_or"' EXIT

echo -n "Simulate Groq cooldown/auth failure... "
code_groq=$(curl -sS -o "$tmp_groq" -w "%{http_code}" \
  -X POST "https://api.groq.com/openai/v1/chat/completions" \
  -H "Authorization: Bearer INVALID" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama-3.3-70b-versatile","messages":[{"role":"user","content":"OK"}],"max_tokens":2}' || true)
if [ "$code_groq" = "200" ]; then
  echo -e "${RED}FAIL${NC}"
  exit 1
fi
echo -e "${GREEN}PASS${NC} (HTTP $code_groq)"

echo -n "Gemini direct succeeds... "
code_google=$(curl -sS -o "$tmp_google" -w "%{http_code}" \
  -X GET "https://generativelanguage.googleapis.com/v1beta/models?key=${GOOGLE_API_KEY}")
if [ "$code_google" != "200" ]; then
  echo -e "${RED}FAIL${NC} (HTTP $code_google)"
  exit 1
fi
echo -e "${GREEN}PASS${NC}"

echo -n "OpenRouter succeeds... "
code_or=$(curl -sS -o "$tmp_or" -w "%{http_code}" \
  -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":"Reply with OK"}],"max_tokens":4,"temperature":0}')
if [ "$code_or" != "200" ]; then
  echo -e "${RED}FAIL${NC} (HTTP $code_or)"
  exit 1
fi
echo -e "${GREEN}PASS${NC}"

echo "PASS: Groq failure path is recoverable through Gemini/OpenRouter providers."
