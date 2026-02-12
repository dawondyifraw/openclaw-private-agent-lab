# OpenClaw Home Lab

OpenClaw Home Lab is a multi-agent Telegram automation stack running one host gateway plus Docker support services (Ollama, RAG, Chroma, translation, sandbox guard/runner). Agents are isolated by routing, memory scope, and tool policy. Runtime state is intentionally separated from tracked code and templates so you can reproduce or recover safely.

## Requirements
- OS: Linux host (this repo assumes Ubuntu-like paths, systemd user services, bash).
- Docker Engine + Docker Compose plugin.
- Node + OpenClaw CLI/gateway installed on host.
- `jq`, `curl`, `rg` for tests/scripts.
- Ollama available at `http://localhost:11434`.
- NVIDIA GPU optional (tests still run without GPU, but GPU checks will warn/fail depending on mode).

## 10-Minute Quick Start
1. Clone and enter the repo.
```bash
git clone https://github.com/dawondyifraw/openclaw-home-lab.git
cd openclaw-home-lab
```

2. Create runtime config from templates.
```bash
cp -n .env.example .env
cp -n openclaw.json.example openclaw.json
for a in main assistant g-coder g-hello anxietychat merry-bot g-moltd; do
  cp -n "agents/$a/agent/agent.yaml.example" "agents/$a/agent/agent.yaml"
done
```

3. Configure secrets.
- Put provider keys/tokens in `.env` (runtime-only, never commit).
- Preferred for sensitive tools: per-tool secret files mounted read-only into sandboxed services; do not pass secrets through agent prompts.

4. Start support plane.
```bash
docker compose up -d
```

5. Sync auth profiles before gateway start.
```bash
bash scripts/sync_auth_profiles.sh
```

6. Start gateway.
```bash
systemctl --user restart openclaw-gateway.service
# or equivalent openclaw gateway command for your host
```

7. Run strict validation.
```bash
OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh
```

## Configuration Map (Tracked vs Runtime)
Tracked in git:
- Code, tests, docs, scripts.
- Policy/schema files and `*.example` templates.
- `agents/*/agent/models.json` and `tools/*.json` definitions.

Runtime-only (never commit):
- `.env`, `openclaw.json`, `**/agent/auth-profiles.json`.
- Telegram offsets: `telegram/update-offset*.json`.
- Sessions, memory, logs, and workspace contents.
- Any `*.bak*` files.

## Workspaces
- Canonical runtime workspace root: `/home/devbox/.openclaw/workspaces`.
- `workspaces/` must contain only `README.md` and per-agent runtime folders.
- `workspaces/` is runtime scratch only; docs/policy live in `docs/` and `agents/`.

## Telegram Setup
1. Put all Telegram chat IDs in `openclaw.json` as strings (quoted).
2. Keep `channels.telegram.groupPolicy` = `allowlist`.
3. Ensure `bindings[]` maps each chat/group to exactly one agent.
4. Verify:
```bash
OPENCLAW_TEST_MODE=strict bash tests/test_allowlist.sh
OPENCLAW_TEST_MODE=strict bash tests/test_telegram_config.sh
```
5. In Telegram, run `/status` in each bound chat to confirm routing.

## Personas
- Runtime persona prompts are loaded from `agents/<agent>/agent/agent.yaml`.
- Templates are tracked at `agents/<agent>/agent/agent.yaml.example`.
- If runtime files are missing, rehydrate from templates (Quick Start step 2).

## Common Errors + Fixes
- `No API key found for provider "ollama"`
  - Run `bash scripts/sync_auth_profiles.sh`.
  - Confirm each `agents/<agent>/agent/auth-profiles.json` has `ollama:default` mapping.
  - Ensure Ollama is reachable: `curl -fsS http://localhost:11434/api/tags`.

- Provider cooldown/rate limit (`429`, cooldown active)
  - Wait for cooldown to expire or switch model with `/model`.
  - Keep fallback chain enabled so Groq/OpenRouter/Ollama can take over.
  - Re-run strict checks: `OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh`.

- Gateway/service unreachable
  - Check systemd logs: `journalctl --user -u openclaw-gateway -n 200 --no-pager`.
  - Check support plane: `docker compose ps`.

## Beginner Runbook
- Step-by-step bootstrap: `docs/BOOTSTRAP_BEGINNER.md`
- Full strict evidence report: `docs/SYSTEM_E2E_REPORT.md`
- Testing modes: `docs/TESTING.md`
