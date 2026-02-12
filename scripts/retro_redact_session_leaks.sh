#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/home/devbox/.openclaw}"
STAMP="$(date +%Y%m%d%H%M%S)"

python3 - "$ROOT" "$STAMP" <<'PY'
import json
import re
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
stamp = sys.argv[2]
sessions = root.glob("agents/*/sessions/*.jsonl")

# Transport-level leak signatures we redact retroactively from stored assistant text.
leak_pat = re.compile(
    r"(^\s*NO(?:[_ ][A-Z0-9_ -]{2,})\b)|(\bNOVELTY:\b)|(\bNO\s+Tremolo\b)|(<sendMessage\b)|(\bNO_PERMISSION_ERROR\b)",
    re.I | re.M,
)

files_touched = 0
messages_redacted = 0

for fp in sessions:
    try:
        lines = fp.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        continue
    out = []
    changed = False
    for line in lines:
        try:
            obj = json.loads(line)
        except Exception:
            out.append(line)
            continue
        msg = obj.get("message")
        if not isinstance(msg, dict) or msg.get("role") != "assistant":
            out.append(json.dumps(obj, ensure_ascii=False))
            continue
        content = msg.get("content")
        if isinstance(content, list):
            new_parts = []
            part_changed = False
            for part in content:
                if isinstance(part, dict) and isinstance(part.get("text"), str):
                    txt = part["text"]
                    if leak_pat.search(txt):
                        part = dict(part)
                        part["text"] = "Temporary issue. Try again."
                        part_changed = True
                        messages_redacted += 1
                new_parts.append(part)
            if part_changed:
                msg = dict(msg)
                msg["content"] = new_parts
                obj = dict(obj)
                obj["message"] = msg
                changed = True
        elif isinstance(content, str):
            if leak_pat.search(content):
                msg = dict(msg)
                msg["content"] = "Temporary issue. Try again."
                obj = dict(obj)
                obj["message"] = msg
                changed = True
                messages_redacted += 1
        out.append(json.dumps(obj, ensure_ascii=False))

    if changed:
        bak = fp.with_suffix(fp.suffix + f".bak.{stamp}")
        shutil.copy2(fp, bak)
        fp.write_text("\n".join(out) + "\n", encoding="utf-8")
        files_touched += 1

print(f"files_touched={files_touched} messages_redacted={messages_redacted}")
PY
