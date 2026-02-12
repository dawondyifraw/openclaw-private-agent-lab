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
if ! rg -q "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_2" "${DIST_FILE}"; then
  echo "FAIL: missing Amharic enforcement marker"
  exit 1
fi
if ! rg -q "looksPlaceholder = /\\^\\\\s\\*\\\\\\[AMHARIC TRANSLATION OF:/i" "${DIST_FILE}"; then
  echo "FAIL: missing Amharic placeholder guard"
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_INTERNAL_MARKER_SUPPRESS_V1_0" "${DIST_FILE}"; then
  echo "FAIL: missing NO_DATA_PASSED suppressor marker"
  exit 1
fi
if ! rg -q "NO_\\(DATA\\|DATA_FOUND\\|DATA_PASSED\\|PERMISSIONS\\|PERMISSION_OR_NO_CONFIGURED_PROVIDER\\|INPUT\\|MESSAGE_CONTENT_HERE\\|API_KEY\\)" "${DIST_FILE}"; then
  echo "FAIL: missing NO_DATA_PASSED suppressor pattern"
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_SENDMESSAGE_CHOKEPOINT_V1_3" "${DIST_FILE}"; then
  echo "FAIL: missing Telegram sendMessage chokepoint marker"
  exit 1
fi
if ! rg -q "path=chokepoint" "${DIST_FILE}"; then
  echo "FAIL: missing Telegram chokepoint telemetry marker"
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_SEND_WRAPPER_STRIP_V1_0|OPENCLAW_TELEGRAM_SEND_WRAPPER_STRIP_V1_1" "${DIST_FILE}"; then
  echo "FAIL: missing pseudo wrapper strip marker"
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_CHOKEPOINT_AMHARIC_ENFORCEMENT_V1_0" "${DIST_FILE}"; then
  echo "FAIL: missing chokepoint Amharic enforcement marker"
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_NO_INPUT_SUPPRESS_V1_0" "${DIST_FILE}"; then
  echo "FAIL: missing NO INPUT suppressor marker"
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_GENERIC_NO_MARKER_SUPPRESS_V1_0" "${DIST_FILE}"; then
  echo "FAIL: missing generic NO_* suppressor marker"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?message\b[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing <message> wrapper strip logic"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?user\b[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing <user> wrapper strip logic"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?assistant\b[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing <assistant> wrapper strip logic"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/^\s*NO_REPLY\s*$/gmi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing bare NO_REPLY strip logic"
  exit 1
fi
if ! rg -Fq 'OPENCLAW_TELEGRAM_EXTRA_WRAPPER_SUPPRESS_V1_0' "${DIST_FILE}"; then
  echo "FAIL: missing extra wrapper suppressor marker"
  exit 1
fi
if ! rg -Fq 'OPENCLAW_TELEGRAM_PERSONA_LEAK_SUPPRESS_V1_0' "${DIST_FILE}"; then
  echo "FAIL: missing persona leak suppressor marker"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?bot_action\b[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing <bot_action> wrapper strip logic"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?begin_inference\b[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing <begin_inference> wrapper strip logic"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?extra\b[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing <extra> wrapper strip logic"
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?transcript\b[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: missing <transcript> wrapper strip logic"
  exit 1
fi
if ! rg -Fq '(?:IDENTITY|USER|HEARTBEAT|BOOTSTRAP|SOUL|MEMORY|MEMORY_POLICY)\.md' "${DIST_FILE}"; then
  echo "FAIL: missing expanded persona-doc leak suppressor pattern"
  exit 1
fi
if ! rg -Fq 'if (identityDocHits + openclawPathLeakHits > 0) t = "";' "${DIST_FILE}"; then
  echo "FAIL: missing persona/path hard-drop logic"
  exit 1
fi

echo "PASS: reply-wrapper sanitizer present in installed bundle"
