#!/usr/bin/env bash
set -euo pipefail

# Archive legacy OpenClaw artifacts into a cold, read-only directory.
# - Non-destructive: moves only allowlisted paths; no deletions.
# - Reversible: restore by moving paths back from the archive.
# - Safety: redacts secrets in the archived copies and disables any archived docker-compose.yml.

DRY_RUN=1
ARCHIVE_DIR_NAME="openclaw""_legacy_""$(date +%F)"
ARCHIVE_ROOT_DEFAULT="/home/devbox/archives/${ARCHIVE_DIR_NAME}"
ARCHIVE_ROOT="$ARCHIVE_ROOT_DEFAULT"

usage() {
  cat <<'EOF'
Usage:
  scripts/archive_legacy.sh [--dry-run] [--execute] [--archive-root PATH]

Modes:
  --dry-run   (default) print actions only
  --execute   perform moves + redactions + chmod a-w on the archive

Notes:
  - This script moves only an explicit allowlist of known-legacy items.
  - It never touches ~/.openclaw/secrets.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --execute) DRY_RUN=0; shift ;;
    --archive-root) ARCHIVE_ROOT="${2:?missing path}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

LIVE_ROOT="/home/devbox/.openclaw"

# Explicit allowlist of legacy items to archive.
ABS_PATHS=(
  "/home/devbox/openclaw"
  "/home/devbox/openclaw-upstream"
)

LIVE_REL_PATHS=(
  "openclaw.json.bak"
  "openclaw.json.bak.1"
  "openclaw.json.bak.2"
  "openclaw.json.bak.3"
  "openclaw.json.bak.4"
  "cron/jobs.json.bak"
  "services/dashboard/dashboard.log"
  "agents/main/agent/auth-profiles.json.bak"
  "__pycache__"
)

say() { printf '%s\n' "$*"; }

ensure_archive_root() {
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] mkdir -p \"$ARCHIVE_ROOT\""
    return 0
  fi
  mkdir -p "$ARCHIVE_ROOT"
}

dest_for_abs() {
  local src="$1"
  # Preserve absolute path structure under the archive.
  local rel
  rel="$(realpath --relative-to=/ "$src")"
  printf '%s/%s' "$ARCHIVE_ROOT" "$rel"
}

move_one() {
  local src="$1"
  if [ ! -e "$src" ]; then
    say "[skip] missing: $src"
    return 0
  fi

 local dest
  dest="$(dest_for_abs "$src")"
  local dest_dir
  dest_dir="$(dirname "$dest")"

  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] mkdir -p \"$dest_dir\""
    say "[dry-run] mv -- \"$src\" \"$dest\""
    return 0
  fi

  mkdir -p "$dest_dir"
  if [ -e "$dest" ]; then
    dest="${dest}.moved.$(date +%s)"
  fi
  mv -- "$src" "$dest"
  say "[moved] $src -> $dest"

  postprocess_archived_path "$dest"
}

redact_env_file() {
  local f="$1"
  # Replace any KEY=VALUE with KEY=REDACTED, preserving variable name and comments.
  python3 - "$f" <<'PY'
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
lines = p.read_text(encoding="utf-8", errors="replace").splitlines(True)
out = []
for line in lines:
    if line.lstrip().startswith("#") or "=" not in line:
        out.append(line)
        continue
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', line.rstrip("\n"))
    if not m:
        out.append(line)
        continue
    k, v = m.group(1), m.group(2)
    # Keep already-placeholder values as-is.
    if v.startswith("${") and v.endswith("}"):
        out.append(f"{k}={v}\n")
        continue
    if v == "" or v.upper() == "REDACTED":
        out.append(f"{k}={v}\n")
        continue
    out.append(f"{k}=REDACTED\n")
p.write_text("".join(out), encoding="utf-8")
PY
}

redact_json_like_file() {
  local f="$1"
  # Best-effort: if it's JSON, redact sensitive keys and secret-looking values.
  python3 - "$f" <<'PY'
import json, re, sys
from pathlib import Path

SENSITIVE_KEYS = re.compile(r'(api[-_]?key|token|secret|password|private[-_]?key|botToken|pairing|key)$', re.I)
SECRET_VALUE = re.compile(r'(sk-[A-Za-z0-9][A-Za-z0-9_-]{10,}|gsk_[A-Za-z0-9_-]{10,}|sk-or-v1-[A-Za-z0-9_-]{10,}|AIza[0-9A-Za-z_-]{10,})')
PEM = re.compile(r'-----BEGIN [A-Z ]+ PRIVATE KEY-----')

def scrub(x):
    if isinstance(x, dict):
        out = {}
        for k, v in x.items():
            if isinstance(k, str) and SENSITIVE_KEYS.search(k):
                out[k] = "REDACTED"
            else:
                out[k] = scrub(v)
        return out
    if isinstance(x, list):
        return [scrub(v) for v in x]
    if isinstance(x, str):
        if PEM.search(x) or SECRET_VALUE.search(x):
            return "REDACTED"
    return x

p = Path(sys.argv[1])
raw = p.read_text(encoding="utf-8", errors="replace")
try:
    obj = json.loads(raw)
except Exception:
    # Not JSON; do a minimal string replacement for obvious secret formats.
    raw = PEM.sub("REDACTED", raw)
    raw = SECRET_VALUE.sub("REDACTED", raw)
    p.write_text(raw, encoding="utf-8")
    raise SystemExit(0)

obj2 = scrub(obj)
p.write_text(json.dumps(obj2, indent=2, ensure_ascii=True, sort_keys=True) + "\n", encoding="utf-8")
PY
}

disable_compose_files_under() {
  local root="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] find \"$root\" -name docker-compose.yml -print (and rename to docker-compose.yml.DISABLED)"
    return 0
  fi
  while IFS= read -r f; do
    mv -- "$f" "${f}.DISABLED"
  done < <(find "$root" -type f -name docker-compose.yml 2>/dev/null || true)
}

postprocess_archived_path() {
  local dest="$1"

  # Disable any docker-compose.yml inside the archived tree.
  disable_compose_files_under "$ARCHIVE_ROOT"

  # Redact secrets in archived configs.
  if [[ "$dest" == *.env ]] || [[ "$(basename "$dest")" == ".env" ]]; then
    redact_env_file "$dest"
  elif [[ "$dest" == *.json ]] || [[ "$dest" == *.jsonl ]] || [[ "$dest" == *.bak ]]; then
    redact_json_like_file "$dest" || true
  fi
}

make_archive_readonly() {
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] chmod -R a-w \"$ARCHIVE_ROOT\""
    return 0
  fi
  chmod -R a-w "$ARCHIVE_ROOT"
}

main() {
  say "Archive root: $ARCHIVE_ROOT"
  ensure_archive_root

  say "== Archiving absolute paths =="
  for p in "${ABS_PATHS[@]}"; do
    move_one "$p"
  done

  say "== Archiving live-root paths =="
  for rel in "${LIVE_REL_PATHS[@]}"; do
    move_one "$LIVE_ROOT/$rel"
  done

  make_archive_readonly
  say "Done."
}

main "$@"
