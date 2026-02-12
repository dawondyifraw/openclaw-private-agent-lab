#!/usr/bin/env bash
# STRICT: ensure harvested leak reports do not expose raw secret-like keys.
set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
if [[ "${MODE}" != "strict" ]]; then
  echo "SKIP: strict-only harvest redaction test"
  exit 0
fi

OUT="/tmp/openclaw-telegram-leak-harvest-redaction.md"
bash /home/devbox/.openclaw/scripts/harvest_telegram_leaks.sh --hours 1 --output "${OUT}" >/tmp/openclaw-harvest-redaction.log 2>&1

if [[ ! -s "${OUT}" ]]; then
  echo "FAIL: harvest output file missing/empty: ${OUT}"
  cat /tmp/openclaw-harvest-redaction.log || true
  exit 1
fi

# Raw secret-like patterns that should never appear.
if rg -n '\bAIza[0-9A-Za-z\-_]{20,}\b' "${OUT}" >/dev/null; then
  echo "FAIL: Google-style API key leaked in harvest report"
  exit 1
fi
if rg -n '\bsk-[A-Za-z0-9\-_]{20,}\b' "${OUT}" >/dev/null; then
  echo "FAIL: sk-* style secret leaked in harvest report"
  exit 1
fi
if rg -n '\bgsk_[A-Za-z0-9\-_]{20,}\b' "${OUT}" >/dev/null; then
  echo "FAIL: gsk_* style secret leaked in harvest report"
  exit 1
fi
if rg -n '\btvly-[A-Za-z0-9\-_]{16,}\b' "${OUT}" >/dev/null; then
  echo "FAIL: Tavily-style secret leaked in harvest report"
  exit 1
fi

echo "PASS: harvest report redaction guard passed"
