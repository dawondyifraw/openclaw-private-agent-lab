#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js}"
PATCH_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches/runtime/openclaw/reply-DptDUVRg.sanitized-tools.patch"
if [ ! -f "$TARGET" ]; then
  echo "Target not found: $TARGET" >&2
  exit 1
fi
if rg -q "OPENCLAW_TELEGRAM_TOOL_GOVERNANCE_V1_1" "$TARGET"; then
  echo "Already patched (sanitized-tools): $TARGET"
  exit 0
fi
patch --forward "$TARGET" "$PATCH_FILE"
echo "Patched: $TARGET"
