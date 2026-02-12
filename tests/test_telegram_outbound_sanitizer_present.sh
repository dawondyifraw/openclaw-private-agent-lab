#!/usr/bin/env bash
# STRICT: Fail if the installed OpenClaw gateway does not include the Telegram
# outbound sanitizer + group tool-visibility hardening markers.

set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"

DIST_FILE="/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js"
MARKER_SANITIZER="OPENCLAW_TELEGRAM_OUTBOUND_SANITIZER_V1_2"
MARKER_TOOLS="OPENCLAW_TELEGRAM_TOOL_GOVERNANCE_V1_1"
MARKER_SUPPRESSOR="OPENCLAW_TELEGRAM_INTERNAL_ERROR_SUPPRESSOR_V1_2"
MARKER_TELEMETRY="OPENCLAW_TELEGRAM_SANITIZER_TELEMETRY_V1_0"

if [ ! -f "$DIST_FILE" ]; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: OpenClaw dist file not found: $DIST_FILE"
    exit 1
  fi
  echo "SKIP: OpenClaw dist file not found: $DIST_FILE"
  exit 0
fi

missing=0
if ! rg -n "$MARKER_SANITIZER" "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: $MARKER_SANITIZER"
  missing=1
fi
if ! rg -n "$MARKER_TOOLS" "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: $MARKER_TOOLS"
  missing=1
fi
if ! rg -n "$MARKER_SUPPRESSOR" "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: $MARKER_SUPPRESSOR"
  missing=1
fi
if ! rg -n "$MARKER_TELEMETRY" "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: $MARKER_TELEMETRY"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: OpenClaw Telegram hardening markers missing from installed gateway bundle."
    echo "Evidence: $DIST_FILE"
    exit 1
  fi
  echo "WARN: OpenClaw Telegram hardening markers missing (default mode)."
  exit 0
fi

echo "PASS: OpenClaw Telegram hardening markers present in installed gateway bundle."
