#!/bin/bash
# tests/test_calendar.sh
# Verifies Calendar service health and port alignment with tool config.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Discover port from tool config
CONFIG="/home/devbox/.openclaw/tools/calendar_read.json"
if [ ! -f "$CONFIG" ]; then
    # Fallback to default check if tool file not found
    CAL_PORT=18821
else
    CAL_PORT=$(jq -r '.endpoint' "$CONFIG" | sed -E 's/.*:([0-9]+).*/\1/')
fi

echo -n "Checking Calendar service on port $CAL_PORT... "
if curl -fsS "http://localhost:$CAL_PORT/health" > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Error: Calendar service is unreachable on port $CAL_PORT."
    exit 1
fi

TOKEN_FILE="/home/devbox/.openclaw/secrets/google_calendar_token.json"
echo -n "Checking OAuth token file permissions... "
if [ -f "$TOKEN_FILE" ]; then
    PERMS=$(stat -c "%a" "$TOKEN_FILE")
    if [ "$PERMS" == "600" ]; then
        echo -e "${GREEN}PASS ($PERMS)${NC}"
    else
        echo -e "${RED}FAIL ($PERMS)${NC}"
        echo "Error: Token file permissions must be 600."
    fi
else
    echo -e "SKIP (Token not yet authorized)"
fi
