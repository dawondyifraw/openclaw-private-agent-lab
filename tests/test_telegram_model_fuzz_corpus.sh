#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/devbox/.openclaw"
CASES_FILE="${BASE_DIR}/tests/data/telegram_model_fuzz_cases.json"

if [[ ! -f "${CASES_FILE}" ]]; then
  echo "FAIL: missing fuzz corpus file: ${CASES_FILE}"
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
    re.compile(r"\bNO_(?:DATA|DATA_FOUND|DATA_PASSED|PERMISSIONS|PERMISSION_OR_NO_CONFIGURED_PROVIDER|PERMISSION_ERROR|INPUT|MESSAGE_CONTENT_HERE|API_KEY)\b", re.I),
    re.compile(r"\bNO\s+INPUT\b", re.I),
    re.compile(r"CANNOT PROCESS", re.I),
    re.compile(r"\bNOVELTY:", re.I),
    re.compile(r"\bNO\s+Tremolo\b", re.I),
    re.compile(r"</?_?reply[^>]*>", re.I),
    re.compile(r"</?sendMessage\b[^>]*>", re.I),
    re.compile(r"</?NO_REPLY\b[^>]*>", re.I),
    re.compile(r"</?searchWeb\b[^>]*>", re.I),
    re.compile(r"\(NO_REPLY\)", re.I),
    re.compile(r"provided both sessionKey and label", re.I),
    re.compile(r"doesn'?t include permissions", re.I),
    re.compile(r"Configuration file:", re.I),
    re.compile(r"Bind address:", re.I),
    re.compile(r"function gateway does not have a valid action set to \"send\"", re.I),
    re.compile(r"using the session_status function", re.I),
    re.compile(r"ImageContext", re.I),
    re.compile(r"</tool_call>", re.I),
]

def classify(text: str) -> str:
    for pat in drop_patterns:
        if pat.search(text):
            return "drop"
    return "allow"

required_ids = {
    "fuzz_tool_wrapper_reply",
    "fuzz_tool_wrapper_sendmessage",
    "fuzz_no_permission_marker",
    "fuzz_http_400_marker",
    "fuzz_heartbeat_marker",
    "fuzz_internal_function_error",
    "fuzz_no_reply_wrapper",
    "fuzz_search_web_wrapper",
    "fuzz_gateway_invalid_action",
}
present_ids = {str(c.get("id")) for c in cases if isinstance(c, dict)}
missing = sorted(required_ids - present_ids)
if missing:
    print(f"FAIL: fuzz corpus missing required ids: {', '.join(missing)}")
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
        fails.append((cid, expect, got, text[:160]))

if fails:
    print(f"FAIL: telegram model fuzz corpus mismatches={len(fails)}")
    for cid, exp, got, sample in fails[:20]:
        print(f" - {cid}: expected={exp} got={got} sample={sample!r}")
    sys.exit(1)

drop_count = sum(1 for c in cases if str(c.get("expect", "")).lower() == "drop")
allow_count = sum(1 for c in cases if str(c.get("expect", "")).lower() == "allow")
print(
    f"PASS: telegram model fuzz corpus validated cases={len(cases)} drop={drop_count} allow={allow_count}"
)
PY
