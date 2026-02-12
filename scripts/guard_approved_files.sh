#!/usr/bin/env bash
set -euo pipefail

# Guard staged files to keep runtime/state artifacts out of commits.
# Usage:
#   bash scripts/guard_approved_files.sh            # checks staged files
#   bash scripts/guard_approved_files.sh --all      # checks tracked+untracked working tree files

MODE="${1:-staged}"

if [[ "${MODE}" == "--all" ]]; then
  mapfile -t files < <(git ls-files && git ls-files --others --exclude-standard)
else
  mapfile -t files < <(git diff --cached --name-only)
fi

if ((${#files[@]} == 0)); then
  echo "PASS: no files to validate."
  exit 0
fi

is_blocked() {
  local p="$1"

  # Explicit blocked runtime/state files.
  [[ "$p" == ".env" ]] && return 0
  [[ "$p" == "openclaw.json" ]] && return 0
  [[ "$p" == "auth-profiles.json" ]] && return 0
  [[ "$p" == "telegram/update-offset-default.json" ]] && return 0

  # Blocked paths/patterns.
  [[ "$p" == memory/* ]] && return 0
  [[ "$p" == workspaces/* ]] && return 0
  [[ "$p" == logs/* ]] && return 0
  [[ "$p" == agents/*/sessions/*.jsonl ]] && return 0
  [[ "$p" == *.bak* ]] && return 0

  return 1
}

is_allowed() {
  local p="$1"
  [[ "$p" == docs/* ]] && return 0
  [[ "$p" == tests/* ]] && return 0
  [[ "$p" == services/* ]] && return 0
  [[ "$p" == docker-compose.yml ]] && return 0
  [[ "$p" == tools/*.json ]] && return 0
  [[ "$p" == *.example ]] && return 0
  return 1
}

blocked=()
warnings=()
for p in "${files[@]}"; do
  [[ -z "$p" ]] && continue
  if is_blocked "$p"; then
    blocked+=("$p")
    continue
  fi
  if ! is_allowed "$p"; then
    warnings+=("$p")
  fi
done

if ((${#blocked[@]} > 0)); then
  echo "FAIL: blocked runtime/state files detected:"
  printf '  - %s\n' "${blocked[@]}"
  exit 1
fi

if ((${#warnings[@]} > 0)); then
  echo "WARN: files outside allowlist detected (not blocked):"
  printf '  - %s\n' "${warnings[@]}"
fi

echo "PASS: approved-files guard passed."
