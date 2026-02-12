#!/bin/bash
# tests/test_allowlist.sh
# Verifies Telegram group allowlist in openclaw.json.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONFIG="/home/devbox/.openclaw/openclaw.json"

echo -n "Checking Telegram groupPolicy... "
POLICY=$(jq -r '.channels.telegram.groupPolicy // empty' "$CONFIG")
if [ -z "$POLICY" ]; then
    echo -e "${YELLOW}SKIP (no channels.telegram.groupPolicy in openclaw.json)${NC}"
    exit 0
fi
if [ "$POLICY" == "allowlist" ]; then
    echo -e "${GREEN}PASS ($POLICY)${NC}"
else
    echo -e "${RED}FAIL ($POLICY)${NC}"
    exit 1
fi

echo "Verifying required Group IDs in groupAllowFrom..."
REQUIRED_IDS=(
    "TG_GROUP_CODER_ID"
    "TG_GROUP_HELLO_ID"
    "TG_GROUP_ANXIETY_CHAT_ID"
    "TG_GROUP_MERRY_ID"
    "-1005251231014"
)

ALLOWED=$(jq -r '.channels.telegram.groupAllowFrom[]' "$CONFIG")
for id in "${REQUIRED_IDS[@]}"; do
    echo -n "  $id: "
    if echo "$ALLOWED" | grep -q "^$id$"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}MISSING${NC}"
        MISSING=true
    fi
done

if [ "$MISSING" == "true" ]; then
    exit 1
fi
