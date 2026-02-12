#!/usr/bin/env bash
set -euo pipefail

LIVE_ROOT="/home/devbox/.openclaw"
CANON="${OPENCLAW_WORKSPACES_ROOT:-$LIVE_ROOT/workspaces}"
COMPAT="$LIVE_ROOT/workspace"

if [ ! -d "$CANON" ]; then
  echo "FAIL: canonical workspaces root missing: $CANON"
  exit 1
fi

if [ ! -e "$COMPAT" ]; then
  echo "FAIL: compatibility path missing: $COMPAT"
  exit 1
fi

RESOLVED="$(readlink -f "$COMPAT")"
RESOLVED_CANON="$(readlink -f "$CANON")"
if [ "$RESOLVED" != "$RESOLVED_CANON" ]; then
  echo "FAIL: $COMPAT resolves to $RESOLVED, expected $RESOLVED_CANON"
  exit 1
fi

echo "PASS: workspace root unified ($COMPAT -> $RESOLVED_CANON)"

