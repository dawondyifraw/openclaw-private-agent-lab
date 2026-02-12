#!/bin/bash
# tests/verify_system_hardening.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "--- System Hardening Verification ---"

# 1. Config Validation
jq . /home/devbox/.openclaw/openclaw.json > /dev/null
if [ $? -eq 0 ]; then
    echo -e "JSON Syntax: ${GREEN}OK${NC}"
else
    echo -e "JSON Syntax: ${RED}FAILED${NC}"
    exit 1
fi

# 2. Main Agent Isolation Check
DEFAULT_AGENT=$(jq -r '.agents.list[] | select(.id=="main") | .default' /home/devbox/.openclaw/openclaw.json)
if [ "$DEFAULT_AGENT" == "false" ]; then
    echo -e "Main Default: ${GREEN}DISABLED${NC}"
else
    echo -e "Main Default: ${RED}ENABLED (STILL DEFAULT)${NC}"
fi

# 3. Binding Uniqueness & Exactly 5 Entries
BINDING_COUNT=$(jq '.bindings | length' /home/devbox/.openclaw/openclaw.json)
if [ "$BINDING_COUNT" -eq 5 ]; then
    echo -e "Binding Count: ${GREEN}5 (CORRECT)${NC}"
else
    echo -e "Binding Count: ${RED}$BINDING_COUNT (EXPECTED 5)${NC}"
fi

DUPE_GROUPS=$(jq -r '.bindings[].match.peer.id' /home/devbox/.openclaw/openclaw.json | sort | uniq -d)
if [ -z "$DUPE_GROUPS" ]; then
    echo -e "Unique Groups: ${GREEN}OK${NC}"
else
    echo -e "Unique Groups: ${RED}DUPLICATES DETECTED: $DUPE_GROUPS${NC}"
fi

# 4. Auth Sync Check
MISSING_AUTH=0
AGENTS=("main" "g-coder" "g-hello" "anxietychat" "merry-bot" "assistant")
for agent in "${AGENTS[@]}"; do
    if [ ! -f "/home/devbox/.openclaw/workspace/agents/$agent/auth-profiles.json" ]; then
        echo -e "Auth for $agent: ${RED}MISSING${NC}"
        MISSING_AUTH=1
    fi
done
if [ $MISSING_AUTH -eq 0 ]; then
    echo -e "Auth Profiles: ${GREEN}SYNCED${NC}"
fi

# 5. Service Health
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" localhost:18821/health)
if [ "$STATUS_CODE" == "200" ]; then
    echo -e "Calendar Health: ${GREEN}OK (200)${NC}"
else
    echo -e "Calendar Health: ${RED}FAILED ($STATUS_CODE)${NC}"
fi

echo "--------------------------------------"
