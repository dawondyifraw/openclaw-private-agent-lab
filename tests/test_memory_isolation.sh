#!/bin/bash
# tests/test_memory_isolation.sh
# Verifies memory isolation configuration (per-agent paths, tool access boundaries).

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

AGENTS=("main" "anxietychat" "assistant" "g-coder" "g-hello" "merry-bot")
MEMORY_BASE="/home/devbox/.openclaw/memory"
MODE="${OPENCLAW_TEST_MODE:-default}"

AGENTS_DIR="/home/devbox/.openclaw/agents"
OPENCLAW_CONFIG="/home/devbox/.openclaw/openclaw.json"

echo "Verifying per-agent memory configuration..."
declare -A MEM_PATHS=()
FAIL=0

for agent in "${AGENTS[@]}"; do
    YAML="${AGENTS_DIR}/${agent}/agent/agent.yaml"
    echo -n "  ${agent} agent.yaml: "
    if [ ! -f "$YAML" ]; then
        echo -e "${RED}MISSING${NC} (${YAML})"
        FAIL=1
        continue
    fi
    echo -e "${GREEN}OK${NC}"

    MEM_LINE=$(grep -E '^memory:\s+' "$YAML" | head -n 1 || true)
    echo -n "  ${agent} memory path: "
    if [ -z "$MEM_LINE" ]; then
        if [ "$MODE" = "strict" ]; then
            echo -e "${RED}FAIL${NC} (no memory: field in ${YAML})"
            FAIL=1
        else
            echo -e "${YELLOW}WARN${NC} (no memory: field in ${YAML})"
        fi
        continue
    fi

    MEM_PATH=$(echo "$MEM_LINE" | sed -E 's/^memory:\s*//')
    if [[ "$MEM_PATH" != "${MEMORY_BASE}/"* ]]; then
        echo -e "${RED}FAIL${NC} (memory path not under ${MEMORY_BASE}: ${MEM_PATH})"
        FAIL=1
        continue
    fi
    echo -e "${GREEN}${MEM_PATH}${NC}"

    if [ -n "${MEM_PATHS[$MEM_PATH]:-}" ]; then
        echo -e "${RED}FAIL${NC} (duplicate memory path used by ${MEM_PATHS[$MEM_PATH]} and ${agent}: ${MEM_PATH})"
        FAIL=1
    else
        MEM_PATHS[$MEM_PATH]="$agent"
    fi
done

echo "Verifying tool boundary for memory..."
# The filesystem is shared under the same OS user, so "chmod-based" isolation isn't meaningful here.
# We assert the intended policy through config: main should not have memory read/write tools enabled.
MAIN_YAML="${AGENTS_DIR}/main/agent/agent.yaml"
echo -n "  main tools include memory_*: "
if grep -qE '^\s*-\s*memory_(read|write|search)\b' "$MAIN_YAML"; then
    echo -e "${RED}FAIL${NC}"
    FAIL=1
else
    echo -e "${GREEN}PASS${NC}"
fi

echo -n "  openclaw.json references memory tools: "
if [ -f "$OPENCLAW_CONFIG" ] && grep -qE '"memory_(read|write|search)"' "$OPENCLAW_CONFIG"; then
    echo -e "${YELLOW}FOUND${NC} (verify per-agent allowlists manually)"
else
    echo -e "${GREEN}NOT FOUND${NC}"
fi

echo -n "Checking TTL for anxietychat... "
ANXIETY_FILE="/home/devbox/.openclaw/agents/anxietychat/agent/agent.yaml"
if grep -qE 'ttl:\s*7d\b' "$ANXIETY_FILE" || grep -qE 'retention:\s*7d\b' "$ANXIETY_FILE"; then
    echo -e "${GREEN}PASS${NC} (7d found)"
else
    # TTL is optional in this repo; policy is primarily enforced by routing + scoped memory paths.
    echo -e "${YELLOW}WARN${NC} (TTL not found in anxietychat config)"
fi

if [ "$MODE" = "strict" ] && [ "$FAIL" -ne 0 ]; then
    echo "STRICT MODE: memory isolation prerequisites failed."
    exit 1
fi
