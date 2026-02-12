#!/bin/bash
# tests/test_systemd.sh
# Verifies if the openclaw-gateway.service is active.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -n "Checking openclaw-gateway.service... "

if systemctl --user is-active openclaw-gateway.service > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Error: openclaw-gateway.service is inactive. Run 'systemctl --user start openclaw-gateway.service'."
    exit 1
fi
