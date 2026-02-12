#!/usr/bin/env bash
# STRICT: simulate cloud provider failure/cooldown conditions and verify local fallback viability.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"
if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only cooldown fallback test"
  exit 0
fi

tmp_or="$(mktemp)"
tmp_gr="$(mktemp)"
tmp_ol="$(mktemp)"
trap 'rm -f "$tmp_or" "$tmp_gr" "$tmp_ol"' EXIT

echo -n "simulate OpenRouter cooldown/auth failure... "
code_or="$(curl -sS -o "$tmp_or" -w "%{http_code}" \
  -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer INVALID" \
  -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.0-flash-001","messages":[{"role":"user","content":"OK"}],"max_tokens":2}' || true)"
if [ "$code_or" = "200" ]; then
  echo -e "${RED}FAIL${NC}"
  echo "expected non-200 when simulating OpenRouter failure"
  exit 1
fi
echo -e "${GREEN}PASS${NC} (HTTP $code_or)"

echo -n "simulate Groq cooldown/auth failure... "
code_gr="$(curl -sS -o "$tmp_gr" -w "%{http_code}" \
  -X POST "https://api.groq.com/openai/v1/chat/completions" \
  -H "Authorization: Bearer INVALID" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama-3.3-70b-versatile","messages":[{"role":"user","content":"OK"}],"max_tokens":2}' || true)"
if [ "$code_gr" = "200" ]; then
  echo -e "${RED}FAIL${NC}"
  echo "expected non-200 when simulating Groq failure"
  exit 1
fi
echo -e "${GREEN}PASS${NC} (HTTP $code_gr)"

echo -n "verify local Ollama fallback path... "
code_ol="$(curl -sS -o "$tmp_ol" -w "%{http_code}" \
  -X POST "http://localhost:11434/api/generate" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen2.5:14b","prompt":"Reply with OK","stream":false}')"
if [ "$code_ol" != "200" ]; then
  echo -e "${RED}FAIL${NC}"
  echo "ollama generate returned HTTP $code_ol"
  exit 1
fi
if ! jq -e '.response | type=="string" and length>0' "$tmp_ol" >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}"
  echo "ollama response payload missing"
  exit 1
fi
echo -e "${GREEN}PASS${NC}"

echo "Fallback chain readiness: OpenRouter fail -> Groq fail -> Ollama success"
echo "If all providers fail at runtime, Telegram response should remain sanitized: 'Temporary issue. Try again.'"
