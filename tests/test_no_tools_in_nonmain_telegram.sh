#!/usr/bin/env bash
# STRICT: Fail if recent non-main Telegram sessions contain disallowed tool calls.
# - For agents with tools: [] => any toolCall is forbidden.
# - For agents with explicit tools list => only listed tools are allowed.
set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"

if ! command -v python3 >/dev/null 2>&1; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: python3 is required"
    exit 1
  fi
  echo "SKIP: python3 not available"
  exit 0
fi

python3 <<'PY'
import glob
import json
import os
import time
from datetime import datetime, timezone
import yaml

BASE = "/home/devbox/.openclaw"
WINDOW_MINUTES = int(os.environ.get("OPENCLAW_RECENT_TOOLCALL_WINDOW_MINUTES", "15"))
CUTOFF = time.time() - WINDOW_MINUTES * 60
RUNTIME_POLICY_FILE = "/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js"
if os.path.exists(RUNTIME_POLICY_FILE):
    CUTOFF = max(CUTOFF, os.path.getmtime(RUNTIME_POLICY_FILE))

agent_tools = {}
for path in glob.glob(os.path.join(BASE, "agents", "*", "agent", "agent.yaml")):
    agent = path.split(os.sep)[-3]
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    tools = data.get("tools") or []
    if not isinstance(tools, list):
        tools = []
    agent_tools[agent] = {str(t).strip() for t in tools if str(t).strip()}

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
        # Handles "...Z" and offsets.
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.timestamp()
    except Exception:
        return None

def is_telegram_session(entries):
    for e in entries:
        msg = (e or {}).get("message") or {}
        if msg.get("role") != "user":
            continue
        for block in msg.get("content") or []:
            txt = block.get("text") if isinstance(block, dict) else None
            if isinstance(txt, str) and "[Telegram" in txt and "id:" in txt:
                return True
    return False

findings = []
for agent_dir in glob.glob(os.path.join(BASE, "agents", "*")):
    agent = os.path.basename(agent_dir)
    if agent == "main":
        continue
    sessions_dir = os.path.join(agent_dir, "sessions")
    if not os.path.isdir(sessions_dir):
        continue
    allowed = agent_tools.get(agent, set())
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
            for block in msg.get("content") or []:
                if not isinstance(block, dict) or block.get("type") != "toolCall":
                    continue
                tool_name = str(block.get("name") or "").strip()
                if tool_name not in allowed:
                    findings.append({
                        "agent": agent,
                        "tool": tool_name,
                        "file": file,
                        "id": (e or {}).get("id"),
                        "allowed": sorted(allowed),
                    })

if findings:
    print("FAIL: disallowed toolCall found in recent non-main Telegram sessions")
    print(f"cutoff_minutes={WINDOW_MINUTES}")
    for f in findings[:20]:
        print(f"- agent={f['agent']} tool={f['tool']} allowed={f['allowed']} file={f['file']} entryId={f['id']}")
    raise SystemExit(1)

print(f"PASS: no disallowed non-main Telegram toolCall entries found in recent sessions (window={WINDOW_MINUTES}m)")
PY
