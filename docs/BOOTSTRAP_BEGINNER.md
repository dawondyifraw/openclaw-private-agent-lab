# Bootstrap Beginner Guide

This guide reproduces a working OpenClaw runtime from a fresh clone with safe defaults.

## 1) Prepare
```bash
cd /home/devbox
git clone https://github.com/dawondyifraw/openclaw-home-lab.git .openclaw
cd /home/devbox/.openclaw
```

## 2) Create runtime files from templates
```bash
cp -n .env.example .env
cp -n openclaw.json.example openclaw.json
for a in main assistant g-coder g-hello anxietychat merry-bot g-moltd; do
  cp -n "agents/$a/agent/agent.yaml.example" "agents/$a/agent/agent.yaml"
done
```

## 3) Fill required runtime secrets
Edit `.env` and set at least:
- `TELEGRAM_BOT_TOKEN`
- `OPENCLAW_GATEWAY_TOKEN`
- `OPENROUTER_API_KEY`
- `GROQ_API_KEY`
- `GOOGLE_API_KEY` (optional in strict if OpenRouter+Groq are healthy)
- `SANDBOX_GUARD_TOKEN`
- `TOOL_RUNNER_TOKEN`

Generate sandbox tokens if needed:
```bash
bash scripts/generate_tokens.sh
```

## 4) Start support services
```bash
docker compose up -d
```

## 5) Sync auth profiles across agents
```bash
bash scripts/sync_auth_profiles.sh
```

## 6) Start gateway
```bash
systemctl --user restart openclaw-gateway.service
```

## 7) Validate strict mode
```bash
OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh
```

Expected: exit code `0` and `PASS` lines for all strict-required modules.

## 8) First successful message test
1. Send `/status` in one mapped Telegram group.
2. Send `hello` in that same group.
3. Confirm:
- Correct agent responds.
- No tool/schema leakage (`<tools>`, `sessions_send`, `MEDIA:`).

Quick log check:
```bash
journalctl --user -u openclaw-gateway --since "5 min ago" --no-pager | rg -n "telegram-sanitize|tool call validation failed|<tools>|MEDIA:"
```

## Safe Defaults
- Keep `OPENCLAW_TEST_MODE=strict` before restarts.
- Keep `groupPolicy=allowlist` and all chat IDs quoted strings.
- Keep `workspaces/` runtime-only.
