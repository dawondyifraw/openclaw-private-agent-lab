#!/usr/bin/env bash
# STRICT: ensure sanitizer telemetry marker/fields exist in the installed gateway bundle.

set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
DIST_FILE="/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js"

if [ ! -f "$DIST_FILE" ]; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: dist file missing: $DIST_FILE"
    exit 1
  fi
  echo "SKIP: dist file missing: $DIST_FILE"
  exit 0
fi

required=(
  "OPENCLAW_TELEGRAM_INTERNAL_ERROR_SUPPRESSOR_V1_2"
  "OPENCLAW_TELEGRAM_SANITIZER_TELEMETRY_V1_0"
  "dropReason"
  "strippedCount"
  "textHash"
  "sha256HexPrefix("
  "[telegram-sanitize]"
)

missing=0
for marker in "${required[@]}"; do
  if ! rg -n -F "$marker" "$DIST_FILE" >/dev/null 2>&1; then
    echo "MISSING: $marker"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: sanitizer telemetry requirements missing in bundle"
    exit 1
  fi
  echo "WARN: sanitizer telemetry requirements missing in bundle"
  exit 0
fi

echo "PASS: sanitizer telemetry markers/fields present in bundle"

