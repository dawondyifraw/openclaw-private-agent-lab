# Telegram Sanitizer Patch Provenance (v1.2)

This note documents the runtime sanitizer/command-guard patch that is applied to the installed OpenClaw bundle.

## Bundle Target

- `/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js`

Note: this file is outside the repository tree; reinstalling/upgrading OpenClaw can overwrite it.

## Marker Families

Static checks in strict mode verify these marker families in the bundle and logs:

- `OPENCLAW_TELEGRAM_OUTBOUND_SANITIZER_V1_2`
- `OPENCLAW_TELEGRAM_INTERNAL_ERROR_SUPPRESSOR_V1_2`
- `OPENCLAW_TELEGRAM_SANITIZER_TELEMETRY_V1_0`

Leakage markers blocked/suppressed include (not exhaustive):

- tool/runtime leakage:
  - `tool call validation failed`
  - `not in request.tools`
  - `sessions_send` templates / `function_call`
  - `Run ID`, `Status: error`, gateway timeout/connect details
- media/tool scaffolding leakage:
  - `MEDIA:`/`.MEDIA:` leak lines
  - TTS scaffolding text
- sentinel/garbage leak markers:
  - `NOBELLA_ERROR`
  - `NO_CONTEXT`, `NOCONTENT`, `NO_MESSAGE_CONTENT_HERE`
  - `NO_DATA_FOUND`, `NO_API_KEY`

## Enforced Behavior

1. Any unknown slash command returns static text.
2. Unknown slash command does **not** call LLM.
3. Telegram output never emits tool diagnostics/internal runtime details.
4. Optional owner-only debug override:
- if `TELEGRAM_DEBUG=true` and `chatId==OPENCLAW_OWNER_TELEGRAM_ID`
- unknown slash command response is: `Unknown command. Use /help, /status.`
5. Main Telegram runtime blocks internal tools (`tts`, `gateway`, `sessions_*`, etc.) for normal chat flow.

## Verification

1. Run strict suite:

```bash
OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh
```

2. Quick Telegram smoke checks after gateway restart:

- In any Telegram chat: `/dock_telegram`
- Expect: `Unknown command. Use /help.`

- In owner DM with `TELEGRAM_DEBUG=true`: `/dock_telegram`
- Expect: `Unknown command. Use /help, /status.`

3. Check logs for leakage markers:

```bash
journalctl --user -u openclaw-gateway --since "10 minutes ago" --no-pager \
  | rg -n "NOBELLA_ERROR|NO_?CONTEXT|NO_?CONTENT|NO_MESSAGE_CONTENT_HERE|NO_DATA_FOUND|NO_API_KEY|tool call validation failed|not in request\\.tools|(^|[^.])MEDIA:|\\.MEDIA:|sessions_send|function_call"
```

Expected: no user-facing leakage hits.
