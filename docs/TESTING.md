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
- Strict requires the *working* providers to be configured: `GOOGLE_API_KEY` + `OPENROUTER_API_KEY` + `GROQ_API_KEY`.
- Kimi and Minimax checks are non-blocking (`EXPECTED_FAIL`) while those providers are disabled from the default chain.

Run:
```bash
cd /home/devbox/.openclaw
OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh
```

## Strict Prerequisites Checklist

- `/home/devbox/.openclaw/.env` contains:
  - `GOOGLE_API_KEY=...`
  - `OPENROUTER_API_KEY=...`
  - `GROQ_API_KEY=...`
  - `SANDBOX_GUARD_TOKEN=REDACTED
  - `TOOL_RUNNER_TOKEN=REDACTED
  - Optional Telegram sanitizer controls:
    - `TELEGRAM_DEBUG=false` (default; diagnostics suppressed globally)
    - `OPENCLAW_OWNER_TELEGRAM_ID=TG_OWNER_ID` (owner DM chat id)
    - `TELEGRAM_SAFE_FALLBACK=false` (default; if true, sends `Temporary issue. Try again.` for dropped non-command messages)
- `/home/devbox/.openclaw/openclaw.json` exists and includes Telegram allowlist + bindings (copy from `openclaw.json.example`).
- Sandbox tokens can be generated (print-only, no writes) via:
```bash
cd /home/devbox/.openclaw
bash scripts/generate_tokens.sh
```

## Telegram Leak Suppression v1.2 Verification

1. Send test traffic in at least 2 Telegram groups + owner DM:
   - `test`
   - `asdsadas`
   - `/status`
   - `/model`
2. Run strict suite:
```bash
cd /home/devbox/.openclaw
OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh
```
3. Confirm sanitizer telemetry (content-free) exists:
```bash
journalctl --user -u openclaw-gateway --since "10 min ago" --no-pager | rg "\\[telegram-sanitize\\]"
```
4. Confirm no forbidden leak patterns in recent Telegram sessions:
```bash
OPENCLAW_TEST_MODE=strict bash tests/test_telegram_internal_leakage_markers.sh
```


## Telegram Command Contract

OpenClaw uses a **default-deny** slash-command guard for Telegram.

- Any message starting with `/` that is **not explicitly allowlisted** must return a static:
  - `Unknown command. Use /help.`
- Unknown slash commands **must not reach the LLM** (prevents tool/schema leaks and prompt injection via commands).
- The global Telegram leak suppressor/sanitizer remains enforced for all Telegram traffic.

### Supported Commands

Global safe commands (everywhere):
- `/help`
- `/status`
- `/model`
- `/new` and `/reset` (if supported by your command system)

Dashboard assistant group (`TG_GROUP_ASSISTANT_DASHBOARD_ID`) commands:
- `/dash` and `/dashboard` (alias of `/dash`)
- `/task add <text>`
- `/task list`
- `/task done <id>`
- `/remind at <YYYY-MM-DD HH:MM> <text>`
- `/remind list`
- `/remind cancel <id>`

### Debug Overrides (Owner DM Only)

- `TELEGRAM_DEBUG=false` (default)
- `OPENCLAW_OWNER_TELEGRAM_ID=<owner_dm_chat_id>`
- `OPENCLAW_ASSISTANT_DASH_GROUP_ID=TG_GROUP_ASSISTANT_DASHBOARD_ID`

### How To Add A New Command Safely

1. Add it to `scripts/patch_telegram_command_allowlist.sh` (marker: `OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1`).
2. Add strict tests:
   - `tests/test_telegram_known_commands.sh`
   - `tests/test_telegram_unknown_commands_static.sh`
3. Run strict:
```bash
cd /home/devbox/.openclaw
OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh
```


## Runtime vs Tracked Files

Untracked/ignored (runtime-only):
- `.env`
- `openclaw.json`
- `auth-profiles.json`
- `memory/**`
- `workspaces/**`
- `update-offset*.json`
- `*.bak*`

## Canonical Workspace Root

Tests use:
- `OPENCLAW_WORKSPACES_ROOT=/home/devbox/.openclaw/workspaces` (exported by the test runner)

Compatibility alias must resolve to the canonical root:
- `/home/devbox/.openclaw/workspace` -> `/home/devbox/.openclaw/workspaces`

Verify:
```bash
readlink -f /home/devbox/.openclaw/workspace
```

## Provider Reality (Current)

- Working and required in strict:
  - Gemini (Google)
  - OpenRouter
  - Groq
- Disabled/non-blocking checks:
  - Kimi
  - Minimax

Strict also runs:
- `tests/test_fallback_under_cooldown.sh` (Groq failure path recovers through Gemini/OpenRouter)
- `tests/test_models_provider_guard.sh` (disabled providers are not switchable in `models.json`)
- `tests/test_no_tools_in_nonmain_telegram.sh` (non-main Telegram sessions cannot execute disallowed tools)
- `tests/test_telegram_language_policy.sh` (English-only agents must not emit large CJK/Thai output blocks in recent Telegram replies)

Optional test windows:
- `OPENCLAW_RECENT_TOOLCALL_WINDOW_MINUTES=15` (default)
- `OPENCLAW_LANGUAGE_WINDOW_MINUTES=15` (default)

## Auto Preflight on Gateway Start

If you want bootstrap + health checks to run automatically before every gateway start/restart:

```bash
cd /home/devbox/.openclaw
bash scripts/install_qa_preflight_systemd.sh
systemctl --user restart openclaw-gateway.service
```

What it does:
- Runs `scripts/qa_preflight.sh` via `ExecStartPre` before `openclaw-gateway.service`.
- Ensures Docker support services are up.
- Verifies key health endpoints.
- Verifies required strict env keys exist.
- Prints GPU snapshot + flash-attention evidence if present.

Optional strict-on-start:
- Set `OPENCLAW_QA_PREFLIGHT_RUN_STRICT=1` in the systemd drop-in if you want full strict tests before each start (slower startup).
