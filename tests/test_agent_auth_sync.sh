#!/bin/bash
# tests/test_agent_auth_sync.sh
# Verifies auth-profiles.json exists for all agents and Ollama is configured for no-auth.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

AGENTS=("main" "anxietychat" "assistant" "g-coder" "g-hello" "merry-bot")
BASE_DIR="/home/devbox/.openclaw/agents"

echo "Checking agent auth profiles..."
for agent in "${AGENTS[@]}"; do
    FILE="$BASE_DIR/$agent/agent/auth-profiles.json"
    echo -n "  $agent: "
    if [ -f "$FILE" ]; then
        echo -e "${GREEN}FOUND${NC}"
        # Check if ollama:default is type: api_key
        if jq -e '.profiles["ollama:default"].type == "api_key"' "$FILE" > /dev/null 2>&1; then
             echo "    [Ollama Auth: api_key]"
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
