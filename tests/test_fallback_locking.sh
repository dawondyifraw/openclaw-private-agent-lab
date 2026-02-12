#!/usr/bin/env bash
# tests/test_fallback_locking.sh
# STRICT: enforce per-agent fallback order for the current local-first routing policy.

set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"
if [ "$MODE" != "strict" ]; then
  echo "SKIP: strict-only fallback locking test"
  exit 0
fi

python3 - <<'PY'
import glob
import os
import sys
import yaml

ROOT = "/home/devbox/.openclaw/agents"
failed = False

expected = {
    "main": {
        "primary": ("ollama", "qwen2.5:14b"),
        "fallbacks": [
            ("ollama", "glm-4.7:latest"),
            ("google", "gemini-2.5-flash"),
            ("openrouter", "google/gemini-2.0-flash-001"),
            ("groq", "llama-3.3-70b-versatile"),
        ],
    },
    "anxietychat": {
        "primary": ("ollama", "qwen2.5:14b"),
        "fallbacks": [
            ("ollama", "glm-4.7:latest"),
            ("openrouter", "google/gemini-2.0-flash-001"),
            ("groq", "llama-3.3-70b-versatile"),
            ("google", "gemini-2.5-flash"),
        ],
    },
    "assistant": {
        "primary": ("ollama", "mistral-nemo:12b"),
        "fallbacks": [
            ("ollama", "qwen2.5:14b"),
            ("mistral", "mistral-large-2411"),
        ],
    },
    "g-coder": {
        "primary": ("ollama", "glm-4.7:latest"),
        "fallbacks": [
            ("ollama", "qwen2.5:14b"),
            ("groq", "llama-3.3-70b-versatile"),
            ("google", "gemini-2.5-flash"),
        ],
    },
    "g-hello": {
        "primary": ("ollama", "wngtcalex/mythomax-13b"),
        "fallbacks": [
            ("ollama", "qwen2.5:14b"),
            ("google", "gemini-2.5-flash"),
        ],
    },
    "g-moltd": {
        "primary": ("ollama", "qwen2.5:14b"),
        "fallbacks": [
            ("ollama", "glm-4.7:latest"),
            ("openrouter", "google/gemini-2.0-flash-001"),
            ("groq", "llama-3.3-70b-versatile"),
            ("google", "gemini-2.5-flash"),
        ],
    },
    "merry-bot": {
        "primary": ("ollama", "wngtcalex/mythomax-13b"),
        "fallbacks": [
            ("ollama", "qwen2.5:14b"),
            ("google", "gemini-2.5-flash"),
        ],
    },
}

for path in sorted(glob.glob(os.path.join(ROOT, "*", "agent", "agent.yaml"))):
    agent = path.split("/")[-3]
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    model = data.get("model", {})
    primary = model.get("primary", {})
    primary_tuple = (str(primary.get("provider", "")), str(primary.get("name", "")))

    fallbacks = []
    for fb in model.get("fallbacks", []) or []:
        fallbacks.append((str(fb.get("provider", "")), str(fb.get("name", ""))))

    # Agent-specific expectations where defined.
    if agent in expected:
        exp = expected[agent]
        if primary_tuple != exp["primary"]:
            print(
                f"FAIL: {agent} primary mismatch. got={primary_tuple} expected={exp['primary']}"
            )
            failed = True
        if fallbacks != exp["fallbacks"]:
            print(
                f"FAIL: {agent} fallback chain mismatch. got={fallbacks} expected={exp['fallbacks']}"
            )
            failed = True

if failed:
    sys.exit(1)

print("PASS: fallback locking + per-agent chains enforced.")
PY
