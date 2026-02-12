#!/usr/bin/env bash
set -euo pipefail

UNIT="openclaw-gateway.service"
SINCE_RAW="$(systemctl --user show -p ActiveEnterTimestamp --value "${UNIT}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
SINCE="$(date -d "${SINCE_RAW}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
SINCE_EPOCH="$(date -d "${SINCE_RAW}" '+%s' 2>/dev/null || true)"
if [[ -z "${SINCE}" ]]; then
  echo "FAIL: unable to resolve ${UNIT} ActiveEnterTimestamp"
  exit 1
fi

PATTERN='HEARTBEAT REPORT|CRON GATEWAY DISCONNECTED|Gateway closed|Configuration file:|Bind address:'
LOG_HITS="$(journalctl --user -u "${UNIT}" --since "${SINCE}" --no-pager | rg -n "${PATTERN}" || true)"
if [[ -n "${LOG_HITS}" ]]; then
  echo "FAIL: heartbeat/diagnostic leakage found in gateway logs since ${SINCE}"
  echo "${LOG_HITS}" | sed -n '1,40p'
  exit 1
fi

SESSION_HITS="$(python3 - "$SINCE_EPOCH" <<'PY'
import json, re, sys
from datetime import datetime
from pathlib import Path

since = int(sys.argv[1])
pat = re.compile(r"HEARTBEAT REPORT|CRON GATEWAY DISCONNECTED|Gateway closed|Configuration file:|Bind address:", re.I)

def parse_epoch(ts: str):
    try:
        return int(datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp())
    except Exception:
        return None

hits = []
for fp in Path("agents").glob("*/sessions/*.jsonl"):
    try:
        with fp.open("r", encoding="utf-8") as f:
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
                msg = obj.get("message") if isinstance(obj, dict) else None
                if not isinstance(msg, dict):
                    continue
                content = msg.get("content")
                texts = []
                if isinstance(content, list):
                    for part in content:
                        if isinstance(part, dict):
                            txt = part.get("text")
                            if isinstance(txt, str):
                                texts.append(txt)
                elif isinstance(content, str):
                    texts.append(content)
                hay = "\n".join(texts)
                if hay and pat.search(hay):
                    hits.append(f"{fp}:{i}:{hay[:400]}")
    except Exception:
        continue

print("\n".join(hits[:40]))
PY
)"
if [[ -n "${SESSION_HITS}" ]]; then
  echo "FAIL: heartbeat/diagnostic leakage found in Telegram session logs since ${SINCE}"
  echo "${SESSION_HITS}" | sed -n '1,40p'
  exit 1
fi

echo "PASS: no heartbeat/diagnostic leakage found since ${SINCE}"
