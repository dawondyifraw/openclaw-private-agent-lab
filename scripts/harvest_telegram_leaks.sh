#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/devbox/.openclaw"
OUT_FILE="${BASE_DIR}/docs/TELEGRAM_LEAK_HARVEST.md"
HOURS="2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hours)
      HOURS="${2:-2}"
      shift 2
      ;;
    --output)
      OUT_FILE="${2:-$OUT_FILE}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      echo "Usage: $0 [--hours N] [--output PATH]" >&2
      exit 2
      ;;
  esac
done

if ! [[ "${HOURS}" =~ ^[0-9]+$ ]] || [[ "${HOURS}" -lt 1 ]]; then
  echo "FAIL: --hours must be a positive integer" >&2
  exit 1
fi

SINCE_HUMAN="$(date -d "-${HOURS} hours" '+%Y-%m-%d %H:%M:%S')"
SINCE_EPOCH="$(date -d "-${HOURS} hours" '+%s')"

mkdir -p "$(dirname "${OUT_FILE}")"

python3 - "${BASE_DIR}" "${OUT_FILE}" "${SINCE_HUMAN}" "${SINCE_EPOCH}" "${HOURS}" <<'PY'
import json
import re
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

base_dir = Path(sys.argv[1])
out_file = Path(sys.argv[2])
since_human = sys.argv[3]
since_epoch = int(sys.argv[4])
hours = int(sys.argv[5])

patterns = [
    ("heartbeat_report", re.compile(r"HEARTBEAT REPORT", re.I)),
    ("cron_gateway_disconnected", re.compile(r"CRON GATEWAY DISCONNECTED", re.I)),
    ("gateway_closed", re.compile(r"Gateway closed", re.I)),
    ("http_status_400_401_403", re.compile(r"\b(?:400|401|403)\s+status code\b", re.I)),
    ("no_marker", re.compile(r"(?:^|\n)\s*NO(?:[_ ][A-Z0-9][A-Z0-9_ -]{1,80})\b", re.I)),
    ("novelty_marker", re.compile(r"\bNOVELTY:", re.I)),
    ("no_tremolo_marker", re.compile(r"\bNO\s+Tremolo\b", re.I)),
    ("reply_wrapper", re.compile(r"</?_?reply[^>]*>", re.I)),
    ("sendmessage_wrapper", re.compile(r"</?sendMessage\b[^>]*>", re.I)),
    ("no_reply_wrapper", re.compile(r"</?NO_REPLY\b[^>]*>", re.I)),
    ("searchweb_wrapper", re.compile(r"</?searchWeb\b[^>]*>", re.I)),
    ("tool_call_trace", re.compile(r"ImageContext|</tool_call>", re.I)),
    ("invalid_gateway_action", re.compile(r"function gateway does not have a valid action set to \"send\"", re.I)),
    ("session_status_hint", re.compile(r"using the session_status function", re.I)),
    ("permission_meta", re.compile(r"doesn'?t include permissions", re.I)),
    ("config_file", re.compile(r"Configuration file:", re.I)),
    ("bind_address", re.compile(r"Bind address:", re.I)),
]

secret_redactions = [
    (re.compile(r"AIza[0-9A-Za-z\-_]{20,}"), "AIza***REDACTED"),
    (re.compile(r"\bsk-[A-Za-z0-9\-_]{10,}\b"), "sk-***REDACTED"),
    (re.compile(r"\bgsk_[A-Za-z0-9\-_]{10,}\b"), "gsk_***REDACTED"),
    (re.compile(r"\btvly-[A-Za-z0-9\-_]{8,}\b"), "tvly-***REDACTED"),
    (re.compile(r"\bBSAQ[A-Za-z0-9\-_]{8,}\b"), "BSAQ***REDACTED"),
]

def redact(s: str) -> str:
    out = s
    for pat, repl in secret_redactions:
        out = pat.sub(repl, out)
    return out

def detect(text: str):
    matched = []
    for name, pat in patterns:
        if pat.search(text):
            matched.append(name)
    return matched

def parse_epoch(ts: str):
    try:
        return int(datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp())
    except Exception:
        return None

counts = Counter()
journal_samples = []
session_samples = []

# Journal scan
journal_cmd = [
    "journalctl", "--user", "-u", "openclaw-gateway.service",
    "--since", since_human, "--no-pager", "-o", "cat"
]
try:
    journal_text = subprocess.check_output(journal_cmd, text=True, stderr=subprocess.DEVNULL)
except Exception:
    journal_text = ""

for idx, line in enumerate(journal_text.splitlines(), 1):
    hits = detect(line)
    if not hits:
        continue
    for h in hits:
        counts[f"journal:{h}"] += 1
    if len(journal_samples) < 60:
        journal_samples.append(f"{idx}: {redact(line.strip())[:600]}")

# Session scan
for fp in base_dir.glob("agents/*/sessions/*.jsonl"):
    try:
        with fp.open("r", encoding="utf-8") as f:
            for i, raw in enumerate(f, 1):
                raw = raw.rstrip("\n")
                if not raw:
                    continue
                try:
                    obj = json.loads(raw)
                except Exception:
                    continue
                ts = obj.get("timestamp")
                if isinstance(ts, str):
                    ep = parse_epoch(ts)
                    if ep is not None and ep < since_epoch:
                        continue
                msg = obj.get("message")
                hay = []
                if isinstance(msg, dict):
                    err = msg.get("errorMessage")
                    if isinstance(err, str):
                        hay.append(err)
                    content = msg.get("content")
                    if isinstance(content, str):
                        hay.append(content)
                    elif isinstance(content, list):
                        for part in content:
                            if isinstance(part, dict):
                                txt = part.get("text")
                                if isinstance(txt, str):
                                    hay.append(txt)
                if not hay:
                    continue
                text = "\n".join(hay)
                hits = detect(text)
                if not hits:
                    continue
                for h in hits:
                    counts[f"session:{h}"] += 1
                if len(session_samples) < 80:
                    sample = redact(text.replace("\n", " "))[:600]
                    session_samples.append(f"{fp}:{i}: {sample}")
    except Exception:
        continue

total_hits = sum(counts.values())
lines = []
lines.append("# Telegram Leak Harvest Report")
lines.append("")
lines.append(f"- Generated: {datetime.now(timezone.utc).isoformat()}")
lines.append(f"- Window: last {hours} hour(s) (since {since_human})")
lines.append(f"- Total candidate hits: {total_hits}")
lines.append("")
lines.append("## Pattern Counts")
if counts:
    lines.append("| Source:Pattern | Count |")
    lines.append("|---|---:|")
    for k, v in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        lines.append(f"| `{k}` | {v} |")
else:
    lines.append("No candidate leak patterns found in the selected window.")

lines.append("")
lines.append("## Journal Samples")
if journal_samples:
    lines.append("```text")
    lines.extend(journal_samples[:60])
    lines.append("```")
else:
    lines.append("No journal samples matched.")

lines.append("")
lines.append("## Session Samples")
if session_samples:
    lines.append("```text")
    lines.extend(session_samples[:80])
    lines.append("```")
else:
    lines.append("No session samples matched.")

lines.append("")
lines.append("## Suggested Follow-ups")
lines.append("- Add any new signature here into `tests/data/telegram_model_fuzz_cases.json` with `expect=drop`.")
lines.append("- Re-run strict suite: `OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh`.")

out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"PASS: wrote leak harvest report -> {out_file}")
print(f"INFO: total candidate hits={total_hits}")
PY
