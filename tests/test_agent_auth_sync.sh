#!/bin/bash
# tests/test_agent_auth_sync.sh
# Verifies auth-profiles.json exists for all agents and Ollama is configured for no-auth.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

BASE_DIR="/home/devbox/.openclaw/agents"

echo "Checking agent auth profiles..."
for agent_path in "$BASE_DIR"/*; do
    [ -d "$agent_path" ] || continue
    agent="$(basename "$agent_path")"
    FILE="$BASE_DIR/$agent/agent/auth-profiles.json"
    echo -n "  $agent: "
    if [ -f "$FILE" ]; then
        echo -e "${GREEN}FOUND${NC}"
        # Check ollama profile is usable by runtime (type + key present).
        if jq -e '.profiles["ollama:default"].type == "api_key" and (.profiles["ollama:default"].key // "") != ""' "$FILE" > /dev/null 2>&1; then
             echo "    [Ollama Auth: api_key + key]"
        else
             echo -e "    ${RED}[Ollama Auth: MISSING/WRONG]${NC}"
             FAIL=true
        fi
    else
        echo -e "${RED}MISSING${NC} at $FILE"
        FAIL=true
    fi
done

if [ "$FAIL" == "true" ]; then
    echo "Error: Auth profile sync check failed."
    echo "Action: Run 'bash /home/devbox/.openclaw/scripts/sync_auth_profiles.sh' after updating the main profile."
    exit 1
fi
