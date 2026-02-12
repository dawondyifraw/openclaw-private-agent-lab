#!/usr/bin/env bash
# STRICT: ensure unknown Telegram slash commands do not reach the LLM (static response).
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
  echo "FAIL: missing allowlist marker (allowlist must exist for default-deny contract)"
  exit 1
fi

# Ensure the unknown slash response text exists (static response).
if ! rg -Fq 'Unknown command. Use /help.' "${DIST_FILE}"; then
  echo "FAIL: missing static unknown command response text"
  exit 1
fi

# Ensure the allowlist isn't accidentally permitting obviously-unknown commands like /dock_telegram.
if rg -q "/dock_telegram" "${DIST_FILE}"; then
  echo "FAIL: found /dock_telegram in runtime bundle; unknown commands must stay default-deny"
  exit 1
fi

echo "PASS: unknown slash commands remain static default-deny"

