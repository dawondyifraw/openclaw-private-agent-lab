#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/devbox/.openclaw/agents"

python3 - <<'PY'
import glob
import os
import re
import sys
import yaml

root = "/home/devbox/.openclaw/agents"
failed = False

for path in sorted(glob.glob(os.path.join(root, "*", "agent", "agent.yaml"))):
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    tools = data.get("tools", [])
    if tools is None:
        tools = []
    if not isinstance(tools, list):
        print(f"FAIL: tools is not a list ({path})")
        failed = True
        continue

    prompt = str(data.get("system_prompt", ""))

    has_no_tools_phrase = "You have NO tools." in prompt
    has_only_phrase = "You may use ONLY:" in prompt

    if len(tools) == 0:
        if not has_no_tools_phrase:
            print(f"FAIL: tools empty but prompt does not say 'You have NO tools.' ({path})")
            failed = True
    else:
        expected = "You may use ONLY: " + ", ".join(tools) + "."
        if has_no_tools_phrase:
            print(f"FAIL: tools defined but prompt says 'You have NO tools.' ({path})")
            failed = True
        if expected not in prompt:
            print(f"FAIL: tools defined but prompt missing exact allow text '{expected}' ({path})")
            failed = True
        if not has_only_phrase:
            print(f"FAIL: tools defined but prompt missing 'You may use ONLY:' ({path})")
            failed = True

if failed:
    sys.exit(1)
print("PASS: tool/prompt consistency")
PY
