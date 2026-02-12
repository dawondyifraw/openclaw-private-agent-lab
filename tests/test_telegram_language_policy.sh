#!/usr/bin/env bash
# STRICT guard: for agents explicitly marked "English only." in prompt,
# fail if recent Telegram assistant replies contain large CJK/Thai script blocks.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not available"
  exit 0
fi

python3 <<'PY'
import glob
import json
import os
import re
import time
import yaml

BASE = "/home/devbox/.openclaw"
WINDOW_MINUTES = int(os.environ.get("OPENCLAW_LANGUAGE_WINDOW_MINUTES", "15"))
CUTOFF = time.time() - WINDOW_MINUTES * 60

# CJK + Thai ranges (conservative leak detector for English-only policies).
NON_EN_BLOCK_RE = re.compile(r"[\u0E00-\u0E7F\u3040-\u30FF\u3400-\u9FFF\U00020000-\U0002A6DF]")

def parse_jsonl(path):
    entries = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return entries

def is_telegram_session(entries):
    for e in entries:
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

english_only_agents = set()
for yaml_path in glob.glob(os.path.join(BASE, "agents", "*", "agent", "agent.yaml")):
    agent = yaml_path.split(os.sep)[-3]
    with open(yaml_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    prompt = str(data.get("system_prompt", ""))
    if "English only." in prompt:
        english_only_agents.add(agent)

if not english_only_agents:
    print("SKIP: no agents explicitly marked 'English only.'")
    raise SystemExit(0)

checked = 0
findings = []
for agent in sorted(english_only_agents):
    sessions_dir = os.path.join(BASE, "agents", agent, "sessions")
    if not os.path.isdir(sessions_dir):
        continue
    for file in glob.glob(os.path.join(sessions_dir, "*.jsonl")):
        if os.path.getmtime(file) < CUTOFF:
            continue
        entries = parse_jsonl(file)
        if not is_telegram_session(entries):
            continue
        for e in entries:
            msg = (e or {}).get("message") or {}
            if msg.get("role") != "assistant":
                continue
            for block in msg.get("content") or []:
                if not isinstance(block, dict) or block.get("type") != "text":
                    continue
                txt = str(block.get("text") or "")
                checked += 1
                hits = NON_EN_BLOCK_RE.findall(txt)
                if len(hits) >= 8:
                    findings.append({
                        "agent": agent,
                        "file": file,
                        "entryId": (e or {}).get("id"),
                        "nonEnglishChars": len(hits),
                        "sample": txt[:120].replace("\n", " "),
                    })

if checked == 0:
    print(f"SKIP: no recent Telegram assistant text for English-only agents in last {WINDOW_MINUTES}m")
    raise SystemExit(0)

if findings:
    print("FAIL: language policy drift detected in English-only Telegram replies")
    for f in findings[:20]:
        print(f"- agent={f['agent']} nonEnglishChars={f['nonEnglishChars']} file={f['file']} entryId={f['entryId']} sample={f['sample']!r}")
    raise SystemExit(1)

print(f"PASS: English-only Telegram language policy respected (checked_blocks={checked}, window={WINDOW_MINUTES}m)")
PY

