#!/usr/bin/env bash
set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
if [[ "${MODE}" != "strict" ]]; then
  echo "SKIP: strict-only"
  exit 0
fi

UNIT="openclaw-gateway.service"
SINCE_RAW="$(systemctl --user show -p ActiveEnterTimestamp --value "${UNIT}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
SINCE_EPOCH="$(date -d "${SINCE_RAW}" '+%s' 2>/dev/null || true)"
if [[ -z "${SINCE_EPOCH}" ]]; then
  echo "FAIL: unable to parse ${UNIT} ActiveEnterTimestamp"
  exit 1
fi

python3 - "$SINCE_EPOCH" <<'PY'
import json
import re
import sys
from datetime import datetime
from pathlib import Path

since = int(sys.argv[1])
pat = re.compile(r"(^\s*NO(?:[_ ][A-Z0-9_ -]{2,})\b)|(\bNOVELTY:\b)|(\bNO\s+Tremolo\b)|(<sendMessage\b)|(\bNO_PERMISSION_ERROR\b)", re.I | re.M)

def parse_epoch(ts: str):
    try:
        return int(datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp())
    except Exception:
        return None

hits = []
for fp in Path("agents").glob("*/sessions/*.jsonl"):
    try:
        with fp.open("r", encoding="utf-8", errors="ignore") as f:
            for i, line in enumerate(f, 1):
                line = line.rstrip("\n")
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                ts = obj.get("timestamp")
                if not isinstance(ts, str):
                    continue
                epoch = parse_epoch(ts)
                if epoch is None or epoch < since:
                    continue
                msg = obj.get("message")
                if not isinstance(msg, dict) or msg.get("role") != "assistant":
                    continue
                content = msg.get("content")
                texts = []
                if isinstance(content, list):
                    for p in content:
                        if isinstance(p, dict):
                            t = p.get("text")
                            if isinstance(t, str):
                                texts.append(t)
                elif isinstance(content, str):
                    texts.append(content)
                text = "\n".join(texts)
                if text and pat.search(text):
                    hits.append(f"{fp}:{i}:{text[:220].replace(chr(10),' | ')}")
    except Exception:
        continue

if hits:
    print("FAIL: recent all-agent language/marker leaks detected")
    for h in hits[:40]:
        print(h)
    sys.exit(1)

print("PASS: no recent all-agent language/marker leaks since service start")
PY
