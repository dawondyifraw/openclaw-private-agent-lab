#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://localhost:18888"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }
need curl
need jq

# 1) Health
curl -fsS "$BASE_URL/health" >/dev/null || fail "tool-runner /health not reachable"
pass "Sandbox Health"

# Prepare workspaces
ROOT="/home/devbox/.openclaw/workspaces"
GCODER="$ROOT/g-coder/group_TG_GROUP_CODER_ID"
GHELLO="$ROOT/g-hello/group_TG_GROUP_HELLO_ID"

mkdir -p "$GCODER" "$GHELLO"
echo "secret-from-g-hello" > "$GHELLO/hello.txt"

# helper to run requests
run_req() {
  curl -sS -X POST "$BASE_URL/run" \
    -H 'Content-Type: application/json' \
    -d "$1"
}

# 2) Workspace containment
# g-coder attempts to read g-hello file via file_read with path traversal -> must be denied
REQ1=$(jq -nc \
  --arg rid "containment" \
  --arg agent "g-coder" \
  --arg chat "TG_GROUP_CODER_ID" \
  '{request_id:$rid,agent:$agent,scope:{type:"telegram",chat_id:$chat},tool:"file_read",args:{path:"../../g-hello/group_TG_GROUP_HELLO_ID/hello.txt"},policy:{fs:{mode:"ro"},net:{mode:"none"},timeout_s:10}}')
R1=$(run_req "$REQ1")
OK1=$(echo "$R1" | jq -r '.ok // empty')
if [ "$OK1" = "true" ]; then
  fail "Workspace containment violated (read succeeded)"
fi
pass "Workspace Containment"

# 3) No secrets exposure: attempt to read .env via traversal
REQ2=$(jq -nc \
  --arg rid "no-secrets" \
  --arg agent "g-coder" \
  --arg chat "TG_GROUP_CODER_ID" \
  '{request_id:$rid,agent:$agent,scope:{type:"telegram",chat_id:$chat},tool:"file_read",args:{path:"../../.env"},policy:{fs:{mode:"ro"},net:{mode:"none"},timeout_s:10}}')
R2=$(run_req "$REQ2")
OK2=$(echo "$R2" | jq -r '.ok // empty')
if [ "$OK2" = "true" ]; then
  fail "Secrets exposure violated (.env read succeeded)"
fi
pass "No Secrets Exposure"

# 4) No internet egress (default)
REQ3=$(jq -nc \
  --arg rid "no-egress" \
  --arg agent "g-coder" \
  --arg chat "TG_GROUP_CODER_ID" \
  '{request_id:$rid,agent:$agent,scope:{type:"telegram",chat_id:$chat},tool:"shell_exec",args:{cmd:["curl","-fsS","https://example.com"]},policy:{fs:{mode:"ro"},net:{mode:"none"},timeout_s:10}}')
R3=$(run_req "$REQ3")
OK3=$(echo "$R3" | jq -r '.ok // empty')
if [ "$OK3" = "true" ]; then
  fail "Internet egress should be blocked"
fi
pass "No Internet Egress (Default)"

# 5) Allowed internal egress
REQ4=$(jq -nc \
  --arg rid "internal-egress" \
  --arg agent "g-coder" \
  --arg chat "TG_GROUP_CODER_ID" \
  '{request_id:$rid,agent:$agent,scope:{type:"telegram",chat_id:$chat},tool:"shell_exec",args:{cmd:["curl","-fsS","http://ollama:11434/api/tags"]},policy:{fs:{mode:"ro"},net:{mode:"allowlist",allow:["ollama"]},timeout_s:10}}')
R4=$(run_req "$REQ4")
OK4=$(echo "$R4" | jq -r '.ok // empty')
if [ "$OK4" != "true" ]; then
  echo "$R4" | jq . || true
  fail "Internal egress to ollama expected OK"
fi
pass "Allowed Internal Egress"

# 6) Tool output sanitization: ensure no traceback
REQ5=$(jq -nc \
  --arg rid "sanitize" \
  --arg agent "g-coder" \
  --arg chat "TG_GROUP_CODER_ID" \
  '{request_id:$rid,agent:$agent,scope:{type:"telegram",chat_id:$chat},tool:"file_read",args:{path:"nope.txt"},policy:{fs:{mode:"ro"},net:{mode:"none"},timeout_s:10}}')
R5=$(run_req "$REQ5")
if echo "$R5" | rg -q "Traceback|File \""; then
  fail "Sanitization violated (traceback leaked)"
fi
pass "Tool Output Sanitization"

