#!/usr/bin/env bash
# STRICT: check recent gateway logs for forbidden leak markers tied to Telegram processing.
# If there is no recent Telegram traffic, SKIP with reason.

set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
DIST_FILE="/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js"

if ! command -v journalctl >/dev/null 2>&1; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: journalctl not available"
    exit 1
  fi
  echo "SKIP: journalctl not available"
  exit 0
fi

if [ ! -f "$DIST_FILE" ]; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: dist file missing: $DIST_FILE"
    exit 1
  fi
  echo "SKIP: dist file missing: $DIST_FILE"
  exit 0
fi

mtime_epoch="$(stat -c %Y "$DIST_FILE" 2>/dev/null || date +%s)"
since="$(date -d "@$mtime_epoch" '+%Y-%m-%d %H:%M:%S')"

LOGS="$(journalctl --user -u openclaw-gateway --since "$since" --no-pager 2>/dev/null || true)"
if [ -z "$LOGS" ]; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: no gateway logs found since $since"
    exit 1
  fi
  echo "SKIP: no gateway logs found since $since"
  exit 0
fi

if ! echo "$LOGS" | rg -q "\\[telegram-sanitize\\]"; then
  echo "SKIP: no recent telegram sanitizer telemetry lines since $since (send Telegram traffic and rerun)"
  exit 0
fi

# Filter out known non-user-facing service startup lines.
FILTERED="$(echo "$LOGS" | rg -v \"listening on ws://127\\.0\\.0\\.1:18789\" || true)"

PATTERN='tool call validation failed|not in request\\.tools|Provide either sessionKey or label|for using `sessionKey`|for using `label`|Gateway timeout|ws://127\\.0\\.0\\.1:18789|<tools>|<toolbox>|function_call|sessions_send|memory_search\\(|(^|[^.])MEDIA:|\\.MEDIA:|\\bRun ID:|\\bStatus:\\s*error|commands\\.restart|\\bNOBELLA_ERROR\\b|\\bNO_?CONTEXT\\b|\\bNO_?CONTENT\\b|\\bNO_MESSAGE_CONTENT_HERE\\b|\\bNO_DATA_FOUND\\b|\\bNO_API_KEY\\b'
if echo "$FILTERED" | rg -n "$PATTERN" >/tmp/openclaw_telegram_no_leak_hits.txt 2>/dev/null; then
  echo "FAIL: forbidden leakage markers present in logs since $since"
  sed -n '1,30p' /tmp/openclaw_telegram_no_leak_hits.txt || true
  exit 1
fi

echo "PASS: no forbidden leakage markers in gateway logs since $since"
