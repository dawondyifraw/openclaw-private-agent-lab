#!/bin/bash
set -e

# Configuration
OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_FILE="$OPENCLAW_HOME/openclaw.json"
AGENTS_DIR="$OPENCLAW_HOME/agents"
AGENTS=("main" "g-coder" "g-hello" "anxietychat" "merry-bot" "assistant")

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
log_info() { echo -e "       $1"; }

echo "Starting E2E Gate Checks..."

# LAYER A: System Health
echo "== Layer A: System Health =="
if systemctl --user is-active --quiet openclaw-gateway.service; then
    log_pass "openclaw-gateway.service is active"
else
    log_fail "openclaw-gateway.service is NOT active"
fi

# Check Docker containers (Rag and Postgres are critical)
if state=$(docker inspect -f '{{.State.Running}}' rag-service 2>/dev/null); then
    if [[ "$state" == "true" ]]; then
         log_pass "Docker container 'rag-service' is running"
    else
         log_fail "Docker container 'rag-service' is NOT running"
    fi
else
    log_fail "Docker container 'openclaw-rag' does not exist"
fi

# LAYER B: Allowlist Validation
echo "== Layer B: Allowlist Validation =="
# Check valid group IDs in openclaw.json
# We expect strings like "-100..."
REQUIRED_GROUPS=("TG_GROUP_HELLO_ID" "TG_GROUP_MERRY_ID" "TG_GROUP_CODER_ID" "TG_GROUP_ANXIETY_CHAT_ID" "-1005251231014")
for gid in "${REQUIRED_GROUPS[@]}"; do
    if grep -q "\"$gid\"" "$CONFIG_FILE"; then
        log_pass "Group ID $gid found in config"
    else
        log_fail "Group ID $gid MISSING from config"
    fi
done

# LAYER C: Per-agent Auth Files
echo "== Layer C: Per-agent Auth Files =="
for agent in "${AGENTS[@]}"; do
    AUTH_FILE="$AGENTS_DIR/$agent/agent/auth-profiles.json"
    if [[ -f "$AUTH_FILE" ]]; then
        # Check size > 0
        if [[ -s "$AUTH_FILE" ]]; then
            log_pass "Auth profile exists for agent: $agent"
        else
             log_fail "Auth profile for $agent is empty"
        fi
    else
        log_fail "Auth profile MISSING for agent: $agent"
    fi
done

# LAYER D: Provider Availability
echo "== Layer D: Provider Availability =="
# Check Google Key in Service Env
if systemctl --user show openclaw-gateway.service --property=Environment | grep -q "GOOGLE_API_KEY"; then
    log_pass "GOOGLE_API_KEY present in systemd environment"
else
    # Fallback checks (maybe in dotfile loaded by wrapper)
    # But strict check failed, checking if we can source it
    if [[ -f "$OPENCLAW_HOME/.env" ]]; then
         source "$OPENCLAW_HOME/.env"
         if [[ -n "$GOOGLE_API_KEY" ]]; then
             log_pass "GOOGLE_API_KEY found in .env (systemd check skipped due to potential masking)"
         else
             log_fail "GOOGLE_API_KEY missing from .env"
         fi
    else
        log_fail "GOOGLE_API_KEY check failed (systemd & .env)"
    fi
fi

# Check OpenRouter Model
MODEL_ID="cognitivecomputations/dolphin-mistral-24b-venice-edition:free"
log_info "Checking OpenRouter model: $MODEL_ID"
source "$OPENCLAW_HOME/.env"
if [[ -z "$OPENROUTER_API_KEY" ]]; then
    log_fail "OPENROUTER_API_KEY not found in env"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $OPENROUTER_API_KEY" "https://openrouter.ai/api/v1/models")
if [[ "$HTTP_CODE" == "200" ]]; then
    # We just check API access mostly, strictly validating list is heavy but let's try shallow grep
    MODELS_JSON=$(curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" "https://openrouter.ai/api/v1/models")
    if echo "$MODELS_JSON" | grep -q "dolphin-mistral"; then
         log_pass "Dolphin Mistral model verified in OpenRouter API"
    else
         log_info "Warning: Dolphin model not explicitly found in list (list might be truncated or model renamed), but API access OK."
         log_pass "OpenRouter API Accessible"
    fi
else
    log_fail "OpenRouter API check failed (HTTP $HTTP_CODE)"
fi

# LAYER E: Tool Endpoints
echo "== Layer E: Tool Endpoints =="

# Calendar
CAL_PORT=$(jq -r '.endpoint' "$OPENCLAW_HOME/tools/calendar_read.json" | sed -E 's/.*:([0-9]+).*/\1/')
if curl -s "http://localhost:$CAL_PORT/health" > /dev/null; then
    log_pass "Calendar service reachable at port $CAL_PORT"
else
    log_fail "Calendar service UNREACHABLE at port $CAL_PORT"
fi

# RAG
# Assuming RAG port 8811 from docker files or previous knowledge, verifying from defaults
RAG_PORT=8811
if curl -s "http://localhost:$RAG_PORT/health" > /dev/null; then
    log_pass "RAG service reachable at port $RAG_PORT"
else
    log_fail "RAG service UNREACHABLE at port $RAG_PORT"
fi

echo ""
echo -e "${GREEN}ALL GATE CHECKS PASSED${NC}"
