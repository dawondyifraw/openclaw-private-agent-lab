#!/usr/bin/env bash
# STRICT: ensure staged changes do not include blocked runtime/state files.
set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only approved-files guard"
  exit 0
fi

bash /home/devbox/.openclaw/scripts/guard_approved_files.sh
