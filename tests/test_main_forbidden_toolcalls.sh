#!/usr/bin/env bash
# STRICT: fail if recent main Telegram sessions contain forbidden tool calls
# that should never appear in normal chat behavior.
set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only main forbidden toolcall check"
  exit 0
fi

python3 <<'PY'
import glob
import json
import os
import time
from datetime import datetime, timezone

BASE = "/home/devbox/.openclaw"
WINDOW_MINUTES = int(os.environ.get("OPENCLAW_MAIN_TOOLCALL_WINDOW_MINUTES", "30"))
window_cutoff = time.time() - WINDOW_MINUTES * 60

# Cutoff-aware: enforce after latest main policy update to avoid failing forever on old logs.
policy_file = "/home/devbox/.openclaw/agents/main/agent/agent.yaml"
runtime_policy_file = "/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js"
effective_after = 0
try:
    effective_after = os.path.getmtime(policy_file)
except Exception:
    effective_after = 0
try:
    effective_after = max(effective_after, os.path.getmtime(runtime_policy_file))
except Exception:
    pass
CUTOFF = max(window_cutoff, effective_after)

FORBIDDEN = {
    "tts",
    "sessions_send",
    "sessions_spawn",
    "sessions_list",
    "sessions_history",
}

def parse_jsonl(path):
    out = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out

def parse_ts(value):
    if not value:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if not isinstance(value, str):
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.timestamp()
    except Exception:
        return None

def is_telegram_session(entries):
    for e in entries:
        ts = parse_ts((e or {}).get("timestamp"))
        if ts is not None and ts < CUTOFF:
            continue
        msg = (e or {}).get("message") or {}
        if msg.get("role") != "user":
            continue
        for block in msg.get("content") or []:
            if not isinstance(block, dict) or block.get("type") != "text":
                continue
            txt = block.get("text")
            if isinstance(txt, str) and "[Telegram" in txt and "id:" in txt:
                return True
    return False

sessions_dir = os.path.join(BASE, "agents", "main", "sessions")
findings = []
for file in glob.glob(os.path.join(sessions_dir, "*.jsonl")):
    if os.path.getmtime(file) < CUTOFF:
        continue
    entries = parse_jsonl(file)
    if not is_telegram_session(entries):
        continue
    for e in entries:
        ts = parse_ts((e or {}).get("timestamp"))
        if ts is not None and ts < CUTOFF:
            continue
        msg = (e or {}).get("message") or {}
        if msg.get("role") != "assistant":
            continue
        for b in msg.get("content") or []:
            if not isinstance(b, dict) or b.get("type") != "toolCall":
                continue
            name = str(b.get("name") or "").strip().lower()
            if name in FORBIDDEN:
                findings.append({
                    "tool": name,
                    "file": file,
                    "entryId": (e or {}).get("id"),
                    "timestamp": (e or {}).get("timestamp"),
                })

if findings:
    print("FAIL: forbidden toolCall(s) found in recent main Telegram sessions")
    print(f"window_minutes={WINDOW_MINUTES} cutoff={time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(CUTOFF))}")
    for f in findings[:20]:
        print(f"- tool={f['tool']} ts={f['timestamp']} file={f['file']} entryId={f['entryId']}")
    raise SystemExit(1)

print(f"PASS: no forbidden main Telegram toolCall entries found in recent sessions (window={WINDOW_MINUTES}m)")
PY
