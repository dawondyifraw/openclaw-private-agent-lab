#!/usr/bin/env bash
# STRICT: verify command routing guard exists so slash commands do not fall through to LLM generation.
# Static bundle checks (no runtime mutation required).

set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
DIST_FILE="/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js"

if [ ! -f "$DIST_FILE" ]; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: dist file missing: $DIST_FILE"
    exit 1
  fi
  echo "SKIP: dist file missing: $DIST_FILE"
  exit 0
fi

missing=0

# Commands are resolved by handlers before model pipeline continuation.
if ! rg -n "const commandResult = await handleCommands\\(" "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: handleCommands invocation"
  missing=1
fi
if ! rg -n "if \\(!commandResult\\.shouldContinue\\) \\{" "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: command short-circuit guard (!shouldContinue)"
  missing=1
fi

# Unknown slash command guard should return without LLM.
if ! rg -n "Unknown command\\. Use /help\\." "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: unknown slash command guard"
  missing=1
fi
if ! rg -n "Unknown command\\. Use /help, /status\\." "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: owner debug unknown slash command hint"
  missing=1
fi

# Guard must apply to any slash input (not only allowTextCommands=true).
if ! rg -n "if \\(normalizedCommandBody\\.startsWith\\(\"/\"\\)\\)" "$DIST_FILE" >/dev/null 2>&1; then
  echo "MISSING: unconditional slash command fallback guard"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: command routing safeguards not found"
    exit 1
  fi
  echo "WARN: command routing safeguards incomplete"
  exit 0
fi

echo "PASS: command routing safeguards present (commands do not fall through to LLM)"
