#!/bin/bash
# tests/test_agent_models_sync.sh
# Verifies models.json is synced from main agent to all active agents.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

BASE_DIR="/home/devbox/.openclaw/agents"
SOURCE="$BASE_DIR/main/agent/models.json"
FAIL=false

if [ ! -f "$SOURCE" ]; then
  echo -e "${RED}FAIL${NC}: missing source models file: $SOURCE"
  exit 1
fi

SRC_SUM="$(sha256sum "$SOURCE" | awk '{print $1}')"
echo "Checking agent model profile sync..."

for agent_path in "$BASE_DIR"/*; do
  [ -d "$agent_path" ] || continue
  agent="$(basename "$agent_path")"
  FILE="$BASE_DIR/$agent/agent/models.json"
  echo -n "  $agent: "
  if [ ! -f "$FILE" ]; then
    echo -e "${RED}MISSING${NC} at $FILE"
    FAIL=true
    continue
  fi

  SUM="$(sha256sum "$FILE" | awk '{print $1}')"
  if [ "$SUM" = "$SRC_SUM" ]; then
    echo -e "${GREEN}SYNCED${NC}"
  else
    echo -e "${RED}DRIFTED${NC}"
    FAIL=true
  fi
done

if [ "$FAIL" = "true" ]; then
  echo "Error: Model profile sync check failed."
  echo "Action: Run 'bash /home/devbox/.openclaw/scripts/sync_model_profiles.sh --apply' after reviewing main models.json."
  exit 1
fi

echo "PASS: all agent model profiles are synced."
