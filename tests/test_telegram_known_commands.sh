#!/usr/bin/env bash
# STRICT: ensure Telegram slash-command allowlist is present and includes dashboard commands.
set -euo pipefail

resolve_dist_file() {
  local default_file="$HOME/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js"
  if [[ -n "${OPENCLAW_REPLY_DIST_FILE:-}" ]]; then
    echo "${OPENCLAW_REPLY_DIST_FILE}"
    return 0
  fi
  if [[ -f "${default_file}" ]]; then
    echo "${default_file}"
    return 0
  fi
  local candidate=""
  candidate="$(ls -1 "$HOME/.local/lib/node_modules/openclaw/dist/reply-"*.js 2>/dev/null | head -n 1 || true)"
  if [[ -n "${candidate}" && -f "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi
  return 1
}

DIST_FILE="$(resolve_dist_file || true)"
if [[ -z "${DIST_FILE}" || ! -f "${DIST_FILE}" ]]; then
  echo "FAIL: missing installed bundle (set OPENCLAW_REPLY_DIST_FILE to override)"
  exit 1
fi

if ! rg -q "OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1" "${DIST_FILE}"; then
  echo "FAIL: missing allowlist marker OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1"
  exit 1
fi

# Verify the allowlist bypass exists (known commands should fall through past the unknown-slash guard).
if ! rg -Fq 'if (isKnownSlashCommand) return { shouldContinue: true };' "${DIST_FILE}"; then
  echo "FAIL: missing allowlist bypass return for known commands"
  exit 1
fi

# Ensure allowlist normalizes To="telegram:<chatId>" into raw chat id before comparison.
if ! rg -Fq 'chatIdStrRaw.startsWith("telegram:") ? chatIdStrRaw.slice(9)' "${DIST_FILE}"; then
  echo "FAIL: missing chatIdStr normalization for telegram:<chatId>"
  exit 1
fi

# Verify dashboard group commands are allowlisted.
if ! rg -q "\\^\\\\/dash\\(\\?:\\\\s\\|\\$\\)" "${DIST_FILE}"; then
  if ! rg -q "\\^\\\\/dash\\(\\?:@\\[A-Za-z0-9_\\]\\+\\)\\?\\(\\?:\\\\s\\|\\$\\)" "${DIST_FILE}"; then
    echo "FAIL: missing /dash allowlist pattern"
    exit 1
  fi
fi
if ! rg -q "\\^\\\\/task\\(\\?:@\\[A-Za-z0-9_\\]\\+\\)\\?\\\\s\\+" "${DIST_FILE}" && ! rg -q "\\^\\\\/task\\\\s\\+\\(\\?:list\\|add" "${DIST_FILE}"; then
  echo "FAIL: missing /task allowlist pattern"
  exit 1
fi
if ! rg -q "\\^\\\\/remind\\(\\?:@\\[A-Za-z0-9_\\]\\+\\)\\?\\\\s\\+" "${DIST_FILE}" && ! rg -q "\\^\\\\/remind\\\\s\\+\\(\\?:list\\|cancel" "${DIST_FILE}"; then
  echo "FAIL: missing /remind allowlist pattern"
  exit 1
fi

# Verify /dashboard alias exists (must map to /dash before unknown-slash guard).
if ! rg -q "OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_1" "${DIST_FILE}"; then
  echo "FAIL: missing /dashboard alias marker"
  exit 1
fi

# Unknown slash commands must still be static.
if ! rg -Fq 'Unknown command. Use /help.' "${DIST_FILE}"; then
  echo "FAIL: missing static unknown command response"
  exit 1
fi

echo "PASS: telegram known-command allowlist present in installed bundle"
