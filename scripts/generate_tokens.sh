#!/usr/bin/env bash
# Print secure tokens for sandbox auth.
# Does NOT write any files; paste output into /home/devbox/.openclaw/.env manually.

set -euo pipefail

python3 - <<'PY'
import secrets

def tok(n=32):
    # URL-safe, no '=' padding
    return secrets.token_urlsafe(n)

print("# Paste these into /home/devbox/.openclaw/.env (do not commit)")
print(f"SANDBOX_GUARD_TOKEN=REDACTED
print(f"TOOL_RUNNER_TOKEN=REDACTED
PY

