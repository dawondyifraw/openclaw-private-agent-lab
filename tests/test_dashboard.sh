#!/bin/bash
# tests/test_dashboard.sh
# Verifies Dashboard storage permissions and JSON schema integrity.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

DASHBOARD_DIR="/home/devbox/.openclaw/data/dashboard"
echo -n "Checking Dashboard storage... "
if [ -d "$DASHBOARD_DIR" ]; then
    if [ -w "$DASHBOARD_DIR" ]; then
        echo -e "${GREEN}WRITABLE${NC}"
    else
        echo -e "${RED}NOT WRITABLE${NC}"
        exit 1
    fi
else
    echo -e "SKIP (Directory not found)"
    exit 0
fi

echo "Verifying JSON integrity for existing data..."
FILES=$(ls "$DASHBOARD_DIR"/*.json 2>/dev/null || true)
if [ -z "$FILES" ]; then
    echo "  No data files found."
else
    for file in $FILES; do
        echo -n "  $(basename "$file"): "
        if jq . "$file" > /dev/null 2>&1; then
             echo -e "${GREEN}OK${NC}"
        else
             echo -e "${RED}CORRUPT${NC}"
             FAIL=true
        fi
    done
fi

if [ "$FAIL" == "true" ]; then
    exit 1
fi
