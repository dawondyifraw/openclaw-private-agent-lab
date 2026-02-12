#!/usr/bin/env bash
# STRICT: ensure Telegram tool-intent relay marker exists and stays allowlist-scoped.
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

if ! rg -q "OPENCLAW_TELEGRAM_TOOL_INTENT_MAIN_RELAY_V1" "${DIST_FILE}"; then
  echo "FAIL: missing tool-intent relay marker"
  exit 1
fi

if ! rg -Fq 'route.agentId !== "main" && !isSlashForToolRelay && hasWebSearchIntent' "${DIST_FILE}"; then
  echo "FAIL: missing strict relay guard (non-main, non-slash, allowlisted intent)"
  exit 1
fi

if ! rg -Fq 'agentId: "main"' "${DIST_FILE}"; then
  echo "FAIL: missing main-agent reroute assignment"
  exit 1
fi

if ! rg -Fq 'replace(/^agent:[^:]+:/, "agent:main:")' "${DIST_FILE}"; then
  echo "FAIL: missing session key remap to main"
  exit 1
fi

echo "PASS: telegram tool-intent relay marker and guards present"
