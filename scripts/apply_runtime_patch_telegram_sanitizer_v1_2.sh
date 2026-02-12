#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js}"
PATCH_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches/runtime/openclaw/reply-DptDUVRg.telegram-sanitizer-v1_2.patch"
if [ ! -f "$TARGET" ]; then
  echo "Target not found: $TARGET" >&2
  exit 1
fi
if rg -q "OPENCLAW_TELEGRAM_OUTBOUND_SANITIZER_V1_2" "$TARGET"; then
  echo "Already patched: $TARGET"
  exit 0
fi
patch --forward "$TARGET" "$PATCH_FILE"
echo "Patched: $TARGET"
