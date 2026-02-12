# Telegram Leak Test Cases

This document defines a practical corpus of high-risk output patterns that must never leak to Telegram chats.

Scope:
- All agents (`main`, `assistant`, `g-coder`, `g-hello`, `merry-bot`, `anxietychat`, `g-moltd`)
- All model paths (cloud and local)
- All outbound paths (LLM replies, command replies, cron/heartbeat, error/diagnostic notices)

## Objectives
- Block internal diagnostics/tooling artifacts from user-visible Telegram output.
- Keep user-facing replies plain, safe, and language-policy compliant.
- Maintain one transport choke point for Telegram text delivery.

## Categories
1. Marker leaks
- `NO_*` variants (`NO_DATA`, `NO_PERMISSION_ERROR`, `NO_INPUT`, etc.)
- `NOVELTY:`, `NO Tremolo`, similar pseudo-diagnostic prefixes

2. Tool/schema leakage
- raw wrapper tags such as `<reply>`, `<_reply>`, `<sendMessage ...>`
- function/tool call templates or argument dumps

3. Runtime/infra leakage
- `HEARTBEAT REPORT`, `CRON GATEWAY DISCONNECTED`, `Gateway closed`
- `Run ID:`, `Status: error`, `Configuration file:`, `Bind address:`
- raw HTTP/provider error strings (`400 status code`, `401`, `403`, timeout text)

4. Language drift leakage
- unsolicited CJK/other-language blocks when policy expects Amharic or user language matching
- mixed garbage/marker + explanatory English paragraphs

5. Garbage/typo stress
- random mixed script and keyboard mash inputs
- short noisy inputs that previously triggered diagnostic templates

6. Wrapper and tool-trace leakage
- `<NO_REPLY>...</NO_REPLY>` artifacts
- pseudo tool wrappers such as `<searchWeb>(query=...)</searchWeb>(NO_REPLY)`
- tool trace fragments like `ImageContext ... </tool_call>`
- internal function-action hints (`function gateway ... action set to "send"`, `session_status function`)

## Expected Behavior
- Internal/diagnostic/tooling content: dropped or replaced with safe fallback.
- In Amharic-enforced chats: normalize to valid Amharic output/fallback.
- Unknown slash commands: static command response path (no LLM diagnostics).
- No raw transport/provider diagnostics visible in Telegram.

## Verification Layers
1. Runtime patch presence tests
- Ensure required sanitizer/chokepoint markers exist in installed bundle.

2. Corpus policy tests
- Validate known-leak strings are classified as `drop` by leak policy.
- Files:
  - `tests/data/telegram_leak_cases.json`
  - `tests/test_telegram_leak_case_corpus.sh`
  - `tests/data/telegram_model_fuzz_cases.json`
  - `tests/test_telegram_model_fuzz_corpus.sh`

3. Recent session regression scan
- Since gateway start, scan all agents' session transcripts for leak signatures.

4. Strict suite gate
- Full strict test run must pass before considering hardening complete.

## Maintenance
- When a new leak appears, add:
  - exact sample to `tests/data/telegram_leak_cases.json`
  - expected action (`drop` or `allow`)
  - corresponding suppressor/policy rule if needed
- Keep false positives low by requiring explicit marker/diagnostic signatures for hard drops.
- Auto-harvest candidates with:
  - `bash scripts/harvest_telegram_leaks.sh --hours 2`
  - review `docs/TELEGRAM_LEAK_HARVEST.md`
  - promote confirmed leaks into `tests/data/telegram_model_fuzz_cases.json`
