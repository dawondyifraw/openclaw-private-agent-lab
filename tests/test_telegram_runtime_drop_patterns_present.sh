#!/usr/bin/env bash
# STRICT: ensure critical leak/drop patterns are present in installed Telegram runtime sanitizer.
set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
if [[ "${MODE}" != "strict" ]]; then
  echo "SKIP: strict-only runtime drop pattern test"
  exit 0
fi

DIST_FILE="${OPENCLAW_REPLY_DIST_FILE:-$HOME/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js}"
if [[ ! -f "${DIST_FILE}" ]]; then
  echo "FAIL: missing bundle: ${DIST_FILE}"
  exit 1
fi

check() {
  local pat="$1"
  local label="$2"
  if ! rg -Fq "$pat" "${DIST_FILE}"; then
    echo "FAIL: missing runtime drop pattern: ${label}"
    exit 1
  fi
}

check "noReplyTagHits = countAndReplace(/<\\/?NO_REPLY\\b[^>]*>/gi, \"\");" "NO_REPLY wrapper strip"
check "searchWebTagHits = countAndReplace(/<\\/?searchWeb\\b[^>]*>/gi, \"\");" "searchWeb wrapper strip"
check "sayTagHits = countAndReplace(/<\\/?say\\b[^>]*>/gi, \"\");" "say wrapper strip"
check "inlineButtonTagHits = countAndReplace(/<\\/?inlineButton\\b[^>]*>/gi, \"\");" "inlineButton wrapper strip"
check "noReplyDashHits = countAndReplace(/^\\s*NO-REPLY\\s*$/gmi, \"\");" "NO-REPLY marker strip"
check "noReplyHyphenTagHits = countAndReplace(/<\\/?no-reply\\b[^>]*>/gi, \"\");" "no-reply tag strip"
check "imStartTokenHits = countAndReplace(/<\\|im_start\\|>/gi, \"\");" "im_start token strip"
check "imEndTokenHits = countAndReplace(/<\\|im_end\\|>/gi, \"\");" "im_end token strip"
check "\\bNOVELTY:" "NOVELTY marker suppress"
check "NO\\s+Tremolo" "NO Tremolo suppress"
check "does not have a valid action" "invalid gateway action suppress"
check "session_status function" "session_status leak suppress"
check "ImageContext" "tool trace suppress"
check "HEARTBEAT REPORT" "heartbeat suppress"
check "CRON GATEWAY DISCONNECTED" "cron diagnostic suppress"
check "\\b(?:400|401|403)\\s+status code\\b" "HTTP status suppress"

echo "PASS: runtime Telegram drop patterns present in installed bundle"
