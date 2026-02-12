# Telegram Bot Tester (tests/telegram_tester_app)

Automated Telegram group testing for OpenClaw bot behavior.

## What Is Configured

- Main bot id: `TG_BOT_ID`
- Bot username: `moltbotd_bot`
- Active groups (5):
  - `assistant_dashboard` -> `TG_GROUP_ASSISTANT_DASHBOARD_ID`
  - `anxiety_chat` -> `TG_GROUP_ANXIETY_CHAT_ID`
  - `g_coder` -> `TG_GROUP_CODER_ID`
  - `g_hello` -> `TG_GROUP_HELLO_ID`
  - `merry_bot` -> `TG_GROUP_MERRY_ID`
- Tester account lock: `TG_TESTER_ID=TG_OWNER_ID`
- Inter-test delay: `TEST_BETWEEN_DELAY=12` seconds

## Canonical Files

- Runner: `tests/telegram_tester_app/telegram_test_automation.py`
- Config: `tests/telegram_tester_app/config.yaml`
- Test suites (canonical): `tests/telegram_tester_app/group_tests.yaml`
- Legacy mirror: `tests/telegram_tester_app/group_test.yaml` (kept in sync)
- Runtime env: `tests/telegram_tester_app/.env`
- Compose: `tests/telegram_tester_app/docker-compose.yml`

## Environment Variables

Required:
- `TG_API_ID`
- `TG_API_HASH`
- `TG_PHONE`
- `TG_PASSWORD` (when Telegram 2FA is enabled)
- `TG_BOT_ID`

Recommended:
- `TG_TESTER_ID` (ensures the logged-in account is the expected tester)
- `TEST_GROUPS` (comma-separated group keys)
- `TEST_BETWEEN_DELAY` (seconds between tests)

Optional:
- `MAX_TESTS` (empty means unlimited)

## Sanitization / Forbidden Pattern Behavior

- Forbidden patterns are read from `config.yaml` -> `forbidden_patterns`.
- Matching behavior in runner:
  - `re:<pattern>` => regex (case-insensitive)
  - any other pattern => literal substring match (case-insensitive)

Examples currently using regex mode:
- `re:tool_[a-z]+`
- `re:api[_-]key`
- `re:session[_-]key`

## Safe Validation (No Telegram API Calls)

Dry-run validates config/groups/test counts only and exits before login/connect/send:

```bash
cd /home/devbox/.openclaw/tests/telegram_tester_app
docker compose run --rm telegram-tester-app \
  python telegram_test_automation.py --dry-run --mode all
```

## Live Test Run

Runs all configured groups and all suites (`normal_tests` + `worst_case_tests`):

```bash
cd /home/devbox/.openclaw/tests/telegram_tester_app
docker compose run --rm -it telegram-tester-app \
  python telegram_test_automation.py --mode all
```

Run only one group:

```bash
docker compose run --rm -it telegram-tester-app \
  python telegram_test_automation.py --groups assistant_dashboard --mode all
```

Run with hard cap:

```bash
docker compose run --rm -it telegram-tester-app \
  python telegram_test_automation.py --mode all --max-tests 10
```

## Reports

Generated under `tests/telegram_tester_app/test_reports/`:
- JSON: `report_*.json`
- HTML: `report_*.html`
