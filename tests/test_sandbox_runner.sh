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
need docker

# Pull token from env first; if not present, try ~/.openclaw/.env; otherwise skip (non-fatal).
if [ -z "${SANDBOX_GUARD_TOKEN:-}" ] && [ -f "/home/devbox/.openclaw/.env" ]; then
  # Avoid ripgrep here: when no match is found it exits 1 and would trip `set -e`.
  SANDBOX_GUARD_TOKEN=REDACTED -n 's/^SANDBOX_GUARD_TOKEN=REDACTED /home/devbox/.openclaw/.env | head -n 1)"
  export SANDBOX_GUARD_TOKEN
fi
if [ -z "${SANDBOX_GUARD_TOKEN:-}" ]; then
  echo "SKIP: SANDBOX_GUARD_TOKEN is not set (sandbox-guard auth test skipped)"
  exit 0
fi

# 1) Health
curl -fsS "$BASE_URL/health" >/dev/null || fail "tool-runner /health not reachable"
pass "Sandbox Health"

# Prepare workspaces
ROOT="${OPENCLAW_WORKSPACES_ROOT:-/home/devbox/.openclaw/workspaces}"
GCODER="$ROOT/g-coder/group_TG_GROUP_CODER_ID"
GHELLO="$ROOT/g-hello/group_TG_GROUP_HELLO_ID"

mkdir -p "$GCODER" "$GHELLO"
echo "secret-from-g-hello" > "$GHELLO/hello.txt"

# helper to run requests
run_req() {
  curl -sS -X POST "$BASE_URL/run" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${SANDBOX_GUARD_TOKEN}" \
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

# 2.1) Spoof attempt: g-coder tries to claim g-hello scope (should be denied by guard allowlist)
REQ_SPOOF=$(jq -nc \
  --arg rid "spoof" \
  --arg agent "g-coder" \
  --arg chat "TG_GROUP_HELLO_ID" \
  '{request_id:$rid,agent:$agent,scope:{type:"telegram",chat_id:$chat},tool:"file_read",args:{path:"hello.txt"}}')
HTTP_CODE=$(curl -sS -o /tmp/sandbox_spoof.json -w '%{http_code}' \
  -X POST "$BASE_URL/run" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${SANDBOX_GUARD_TOKEN}" \
  -d "$REQ_SPOOF")
if [ "$HTTP_CODE" != "403" ]; then
  cat /tmp/sandbox_spoof.json || true
  fail "Spoof attempt expected 403, got $HTTP_CODE"
fi
pass "Spoof Attempt Denied"

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

# 5.1) Direct tool-runner call without token must be denied (401).
REQ_TR=$(jq -nc \
  --arg agent "g-coder" \
  --arg chat "TG_GROUP_CODER_ID" \
  '{agent:$agent,scope:{type:"telegram",chat_id:$chat},tool:"file_read",args:{path:"hello.txt"}}')
CODE_TR=$(docker exec tool-runner curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "http://localhost:18889/run" \
  -H 'Content-Type: application/json' \
  -d "$REQ_TR" || true)
if [ "$CODE_TR" != "401" ]; then
  fail "Direct tool-runner call without token expected 401, got $CODE_TR"
fi
pass "Tool-Runner Auth Required"

# 5.2) RW enforcement: shell_exec runs with a RO mount; write should fail.
REQ_RW=$(jq -nc \
  --arg rid "rw-denied" \
  --arg agent "g-coder" \
  --arg chat "TG_GROUP_CODER_ID" \
  '{request_id:$rid,agent:$agent,scope:{type:"telegram",chat_id:$chat},tool:"shell_exec",args:{cmd:["python3","-c","open(\"rw_test.txt\",\"w\").write(\"x\")"]}}')
R_RW=$(run_req "$REQ_RW")
OK_RW=$(echo "$R_RW" | jq -r '.ok // empty')
if [ "$OK_RW" = "true" ]; then
  fail "RW enforcement violated (shell_exec write succeeded)"
fi
pass "RW Enforcement (RO Mount)"

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
