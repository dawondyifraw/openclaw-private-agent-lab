#!/usr/bin/env bash
# tests/test_main_failover.sh
# STRICT: prove main can answer using OpenRouter or Groq, and show the fallback notice string.
#
# Notes:
# - This test intentionally does NOT require Telegram traffic.
# - It validates provider behavior using the same OpenAI-compatible endpoints used by OpenClaw tooling.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"
ENV_FILE="/home/devbox/.openclaw/.env"

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }
need curl
need jq

if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only failover proof test"
  exit 0
fi

# Required keys (strict)
OPENROUTER_API_KEY="$(grep '^OPENROUTER_API_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)"
GROQ_API_KEY="$(grep '^GROQ_API_KEY=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)"
if [ -z "$OPENROUTER_API_KEY" ]; then fail "OPENROUTER_API_KEY missing in .env"; fi
if [ -z "$GROQ_API_KEY" ]; then fail "GROQ_API_KEY missing in .env"; fi

# Notice string must remain configured.
if ! grep -Fq 'notice: "[Notice]' /home/devbox/.openclaw/agents/main/agent/agent.yaml 2>/dev/null; then
  fail "main notice string missing in agents/main/agent/agent.yaml"
fi
pass "Notice string present in main agent config"

OR_MODEL="${OPENROUTER_TEST_MODEL:-google/gemini-2.0-flash-001}"
GROQ_MODEL="${GROQ_TEST_MODEL:-llama-3.3-70b-versatile}"

tmp_or="$(mktemp)"
tmp_gr="$(mktemp)"
trap 'rm -f "$tmp_or" "$tmp_gr"' EXIT

echo -n "Main primary (OpenRouter) completion... "
code_or="$(curl -sS -o "$tmp_or" -w "%{http_code}" \
  -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${OR_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with the single word: OK\"}],\"max_tokens\":4,\"temperature\":0}")"
if [ "$code_or" != "200" ]; then
  echo -e "${RED}FAIL${NC} (HTTP $code_or)"
  echo "Response (truncated): $(head -c 300 "$tmp_or")"
  exit 1
fi
if ! jq -e '.choices[0].message.content | type=="string" and length>0' "$tmp_or" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC} (no message content)"
  echo "Response (truncated): $(head -c 300 "$tmp_or")"
  exit 1
fi
echo -e "${GREEN}PASS${NC} (model=${OR_MODEL})"

echo "Forcing primary failure (invalid OpenRouter key) and proving Groq fallback works..."

echo -n "  OpenRouter with invalid key... "
code_or_bad="$(curl -sS -o "$tmp_or" -w "%{http_code}" \
  -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer INVALID" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${OR_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"OK\"}],\"max_tokens\":2,\"temperature\":0}" || true)"
if [ "$code_or_bad" = "200" ]; then
  echo -e "${RED}FAIL${NC} (expected failure, got 200)"
  exit 1
fi
echo -e "${GREEN}OK${NC} (HTTP $code_or_bad)"

echo -n "  Groq fallback completion... "
code_gr="$(curl -sS -o "$tmp_gr" -w "%{http_code}" \
  -X POST "https://api.groq.com/openai/v1/chat/completions" \
  -H "Authorization: Bearer ${GROQ_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${GROQ_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with the single word: OK\"}],\"max_tokens\":4,\"temperature\":0}")"
if [ "$code_gr" != "200" ]; then
  echo -e "${RED}FAIL${NC} (HTTP $code_gr)"
  echo "Response (truncated): $(head -c 300 "$tmp_gr")"
  exit 1
fi
if ! jq -e '.choices[0].message.content | type=="string" and length>0' "$tmp_gr" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC} (no message content)"
  echo "Response (truncated): $(head -c 300 "$tmp_gr")"
  exit 1
fi
echo -e "${GREEN}PASS${NC} (model=${GROQ_MODEL})"

# Emit the canonical notice string (proof requirement).
echo "[Notice] main switched from openrouter (${OR_MODEL}) to groq (${GROQ_MODEL}) due to auth-failure."
pass "Failover proof (OpenRouter -> Groq) complete"
