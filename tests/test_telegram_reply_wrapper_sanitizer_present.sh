#!/usr/bin/env bash
# STRICT: ensure installed Telegram sanitizer strips <reply> wrapper artifacts.
set -euo pipefail

DIST_FILE="${OPENCLAW_REPLY_DIST_FILE:-$HOME/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js}"

if [[ ! -f "${DIST_FILE}" ]]; then
  echo "FAIL: missing bundle: ${DIST_FILE}"
  exit 1
fi

if ! rg -q "OPENCLAW_TELEGRAM_REPLY_WRAPPER_STRIP_V1_1" "${DIST_FILE}"; then
  echo "FAIL: missing wrapper-strip marker"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?_?reply[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing underscore reply-wrapper strip logic"
  exit 1
fi
if ! rg -Fq 'wrappedReplyMatch = t.match(/^\s*<_?reply[^>]*>([\s\S]*?)<\/_?reply>\s*$/i);' "${DIST_FILE}"; then
  echo "FAIL: missing wrapped reply match logic"
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_TEXTMODE_EMOJI_V1_0" "${DIST_FILE}"; then
  echo "FAIL: missing emoji textmode marker"
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_0" "${DIST_FILE}"; then
  echo "FAIL: missing Amharic enforcement marker"
  exit 1
fi

echo "PASS: reply-wrapper sanitizer present in installed bundle"
