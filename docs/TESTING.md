# Testing Modes (default vs strict)

This repo supports two test modes controlled by `OPENCLAW_TEST_MODE`.

## Modes

### default

- Best-effort verification.
- Some modules may `SKIP` or `WARN` when prerequisites are missing (e.g., missing provider keys, missing Telegram config blocks, missing recent Telegram log evidence).

Run:
```bash
cd /home/devbox/.openclaw
bash tests/run_all_tests.sh
```

### strict

- Hard-fail verification.
- Any missing prerequisite fails the corresponding module (no silent green).
- `tests/run_all_tests.sh` exits non-zero if any module fails.
- Strict requires the *working* providers to be configured: `OPENROUTER_API_KEY` + `GROQ_API_KEY`.
- Gemini direct (`GOOGLE_API_KEY`) and Minimax are optional in strict (not required to pass).

Run:
```bash
cd /home/devbox/.openclaw
OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh
```

## Strict Prerequisites Checklist

- `/home/devbox/.openclaw/.env` contains:
  - `OPENROUTER_API_KEY=...`
  - `GROQ_API_KEY=...`
  - `SANDBOX_GUARD_TOKEN=REDACTED
  - `TOOL_RUNNER_TOKEN=REDACTED
- `/home/devbox/.openclaw/openclaw.json` exists and includes Telegram allowlist + bindings (copy from `openclaw.json.example`).
- Sandbox tokens can be generated (print-only, no writes) via:
```bash
cd /home/devbox/.openclaw
bash scripts/generate_tokens.sh
```

## Canonical Workspace Root

Tests use:
- `OPENCLAW_WORKSPACES_ROOT=/home/devbox/.openclaw/workspaces` (exported by the test runner)

Compatibility alias must resolve to the canonical root:
- `/home/devbox/.openclaw/workspace` -> `/home/devbox/.openclaw/workspaces`

Verify:
```bash
readlink -f /home/devbox/.openclaw/workspace
```
