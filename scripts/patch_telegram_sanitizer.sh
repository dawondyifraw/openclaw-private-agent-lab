#!/usr/bin/env bash
# Telegram runtime outbound sanitizer patch entrypoint.
# This keeps preflight split-patch flow working even when allowlist patch is separate.
set -euo pipefail

ROOT="/home/devbox/.openclaw"
LEGACY_PATCH="${ROOT}/scripts/patch_telegram_reply_wrapper_sanitizer.sh"

if [[ ! -x "${LEGACY_PATCH}" ]]; then
  echo "FAIL: missing sanitizer patch helper: ${LEGACY_PATCH}" >&2
  exit 1
fi

bash "${LEGACY_PATCH}"
