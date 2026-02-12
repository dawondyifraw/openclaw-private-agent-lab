#!/usr/bin/env bash
# Patch installed OpenClaw runtime so opaque Google/OpenAI-compat transient
# failures (e.g. "400 status code (no body)") are treated as failover-eligible.
set -euo pipefail

DIST_DIR="${OPENCLAW_DIST_DIR:-$HOME/.local/lib/node_modules/openclaw/dist}"
shopt -s nullglob
targets=("${DIST_DIR}"/pi-embedded-helpers-*.js)
shopt -u nullglob

if [ "${#targets[@]}" -eq 0 ]; then
  echo "FAIL: no helper bundles found under ${DIST_DIR}" >&2
  exit 1
fi

patched=0
checked=0

for f in "${targets[@]}"; do
  case "$f" in
    *.bak*|*.orig*) continue ;;
  esac
  checked=$((checked + 1))

  if rg -q '"status code \(no body\)"' "$f"; then
    continue
  fi

  cp "$f" "${f}.bak.compat.$(date +%Y%m%d%H%M%S)"
  perl -0777 -i -pe '
    s/timeout:\s*\[\n\s*"timeout",\n\s*"timed out",\n\s*"deadline exceeded",\n\s*"context deadline exceeded"\n\s*\]/timeout: [\n\t\t"timeout",\n\t\t"timed out",\n\t\t"deadline exceeded",\n\t\t"context deadline exceeded",\n\t\t"status code (no body)",\n\t\t\/\\b(?:4|5)\\d\\d status code \\(no body\\)\\b\/\n\t]/g
  ' "$f"

  if ! rg -q '"status code \(no body\)"' "$f"; then
    echo "FAIL: patch verification failed for $f" >&2
    exit 1
  fi
  patched=$((patched + 1))
done

if [ "$checked" -eq 0 ]; then
  echo "FAIL: no eligible helper bundles found under ${DIST_DIR}" >&2
  exit 1
fi

echo "PASS: compat failover patch verified (patched=${patched}, checked=${checked})"
