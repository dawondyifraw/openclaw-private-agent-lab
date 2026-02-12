#!/usr/bin/env bash
# STRICT: ensure installed OpenClaw helper bundles include compat transient
# error failover markers used for fallback classification.
set -euo pipefail

DIST_DIR="${OPENCLAW_DIST_DIR:-$HOME/.local/lib/node_modules/openclaw/dist}"
shopt -s nullglob
targets=("${DIST_DIR}"/pi-embedded-helpers-*.js)
shopt -u nullglob

if [ "${#targets[@]}" -eq 0 ]; then
  echo "FAIL: no helper bundles found under ${DIST_DIR}"
  exit 1
fi

checked=0
for f in "${targets[@]}"; do
  case "$f" in
    *.bak*|*.orig*) continue ;;
  esac
  checked=$((checked + 1))
  if ! rg -q '"status code \(no body\)"' "$f"; then
    echo "FAIL: missing compat marker in $(basename "$f")"
    exit 1
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "FAIL: no eligible helper bundles found under ${DIST_DIR}"
  exit 1
fi

echo "PASS: compat failover markers present in helper bundles (${checked} checked)"
