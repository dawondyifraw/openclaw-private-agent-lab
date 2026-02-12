#!/usr/bin/env bash
set -euo pipefail

OUT="/tmp/openclaw-telegram-leak-harvest-test.md"

bash /home/devbox/.openclaw/scripts/harvest_telegram_leaks.sh --hours 1 --output "${OUT}" >/tmp/openclaw-harvest-test.log 2>&1

if [[ ! -s "${OUT}" ]]; then
  echo "FAIL: harvest output file missing/empty: ${OUT}"
  cat /tmp/openclaw-harvest-test.log || true
  exit 1
fi

if ! rg -q "^# Telegram Leak Harvest Report" "${OUT}"; then
  echo "FAIL: report header missing"
  exit 1
fi
if ! rg -q "^## Pattern Counts" "${OUT}"; then
  echo "FAIL: report pattern section missing"
  exit 1
fi
if ! rg -q "^## Journal Samples" "${OUT}"; then
  echo "FAIL: report journal samples section missing"
  exit 1
fi
if ! rg -q "^## Session Samples" "${OUT}"; then
  echo "FAIL: report session samples section missing"
  exit 1
fi

echo "PASS: telegram leak harvest tool produced expected report structure"
