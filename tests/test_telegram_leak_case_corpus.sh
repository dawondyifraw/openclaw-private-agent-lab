#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/devbox/.openclaw"
CASES_FILE="${BASE_DIR}/tests/data/telegram_leak_cases.json"

if [[ ! -f "${CASES_FILE}" ]]; then
  echo "FAIL: missing corpus file: ${CASES_FILE}"
  exit 1
fi

python3 - "${CASES_FILE}" <<'PY'
import json
import re
import sys
from pathlib import Path

cases_file = Path(sys.argv[1])
cases = json.loads(cases_file.read_text(encoding="utf-8"))

drop_patterns = [
    re.compile(r"HEARTBEAT REPORT", re.I),
    re.compile(r"CRON GATEWAY DISCONNECTED", re.I),
    re.compile(r"Gateway closed", re.I),
    re.compile(r"\b(?:400|401|403)\s+status code\b", re.I),
    re.compile(r"ws://127\.0\.0\.1", re.I),
    re.compile(r"Run ID:", re.I),
    re.compile(r"Status:\s*error", re.I),
    re.compile(r"Configuration file:", re.I),
    re.compile(r"Bind address:", re.I),
    re.compile(r"(?:^|\n)\s*NO(?:[_ ][A-Z0-9][A-Z0-9_ -]{1,80})\b", re.I),
    re.compile(r"NOVELTY:", re.I),
    re.compile(r"\bNO\s+Tremolo\b", re.I),
    re.compile(r"</?_?reply[^>]*>", re.I),
    re.compile(r"</?sendMessage\b[^>]*>", re.I),
    re.compile(r"\b(?:IDENTITY|USER|HEARTBEAT|BOOTSTRAP|SOUL|MEMORY|MEMORY_POLICY)\.md\b", re.I),
    re.compile(r"https?://(?:identity|user|heartbeat|soul|bootstrap|memory)\.md/?", re.I),
    re.compile(r"/home/devbox/\.openclaw", re.I),
    re.compile(r"</?(?:bot_action|begin_inference|end_inference|extra|transcript|speech|speaker)\b[^>]*>", re.I),
]

def classify(text: str) -> str:
    for pat in drop_patterns:
        if pat.search(text):
            return "drop"
    return "allow"

required_drop_case_ids = {
    "diag_heartbeat",
    "diag_cron_gateway_disconnected",
    "diag_gateway_closed",
    "diag_http_400",
    "diag_run_id",
    "diag_status_error",
    "diag_configuration_file",
    "diag_bind_address",
    "private_workspace_path_leak",
}

found_ids = {c.get("id") for c in cases if isinstance(c, dict)}
missing = sorted(required_drop_case_ids - found_ids)
if missing:
    print(f"FAIL: corpus missing required case ids: {', '.join(missing)}")
    sys.exit(1)

fails = []
for case in cases:
    if not isinstance(case, dict):
        fails.append(("non_dict_case", "invalid", "allow", str(case)))
        continue
    cid = str(case.get("id", "<no-id>"))
    text = str(case.get("text", ""))
    expect = str(case.get("expect", "allow")).lower()
    got = classify(text)
    if expect not in {"allow", "drop"}:
        fails.append((cid, expect, got, "invalid expect value"))
        continue
    if got != expect:
        fails.append((cid, expect, got, text[:140]))

if fails:
    print(f"FAIL: telegram leak corpus mismatches={len(fails)}")
    for cid, exp, got, sample in fails[:20]:
        print(f" - {cid}: expected={exp} got={got} sample={sample!r}")
    sys.exit(1)

drop_count = sum(1 for c in cases if str(c.get("expect", "")).lower() == "drop")
allow_count = sum(1 for c in cases if str(c.get("expect", "")).lower() == "allow")
print(
    f"PASS: telegram leak corpus validated cases={len(cases)} drop={drop_count} allow={allow_count}"
)
PY
