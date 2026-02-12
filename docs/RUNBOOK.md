# OpenClaw Home Lab Runbook

## 🚀 Bootstrap Order

Follow this exact order to ensure a stable system start:

1.  **Set Environment Keys**: populate `~/.openclaw/.env` with your API keys.
2.  **Start Docker Support Services**: 
    ```bash
    docker compose -f ~/.openclaw/docker-compose.yml up -d
    ```
3.  **Verify Health Endpoints**: Ensure port connectivity is green (see checklist below).
4.  **Start OpenClaw Gateway**:
    ```bash
    systemctl --user start openclaw-gateway.service
    ```
5.  **Run E2E Verification**:
    ```bash
    bash ~/.openclaw/tests/run_all_tests.sh
    ```
6.  **Production Ready**: Only after all tests PASS should you start interacting via Telegram.

### Stop System
```bash
# Stop support services
docker compose -f ~/.openclaw/docker-compose.yml down

# Stop OpenClaw gateway
systemctl --user stop openclaw-gateway.service
```

### Restart & Refresh
```bash
systemctl --user restart openclaw-gateway.service
```

## Operational Availability Checklist
Before considering the system "UP", verify the following:
- [ ] `systemctl --user is-active openclaw-gateway.service` is **active**.
- [ ] `docker ps` shows all 4 support containers.
- [ ] `curl -fsS http://localhost:11434/api/tags` returns local models.
- [ ] `curl -fsS http://localhost:8811/health` returns logic status `ok`.
- [ ] `curl -fsS http://localhost:18790/health` returns status `ok` (Amharic).
- [ ] `nvidia-smi` shows GPU visibility (if applicable).

## common Mistakes & Fixes

### 1. "Command Not Found" for `openclaw`
- **Cause**: Path not initialized in current shell.
- **Fix**: `export PATH="$HOME/.local/bin:$PATH"`

### 2. Path Confusion (Relative vs Absolute)
- **Cause**: Running ingestion or scripts from outside `~/.openclaw`.
- **Fix**: Always `cd ~/.openclaw` before running operational scripts.

### 3. Starting Gateway Before Support Services
- **Cause**: Gateway fails to connect to Ollama or Redis on startup.
- **Fix**: Ensure `docker compose up -d` is complete before starting the systemd service.

### 4. Accidental Data Wipe
- **Cause**: Running `docker system prune -a` or `docker volume prune`.
- **Fix**: **ONLY** use `docker compose down` to stop services. Avoid global pruning unless decommissioning.

### 5. Non-Invasive Testing Misconceptions
- **Cause**: Assuming all test scripts are safe.
- **Fix**: Our `tests/run_all_tests.sh` uses isolated paths (`/tmp/openclaw-test-memory`). Other manual scripts might write to production memory; always check script logic before running on production models.

## Persistence & Protection
Local LLM models and RAG vector data are stored in **named Docker volumes** (`ollama_models`, `chroma_data`).

- **Protection**: These volumes survive `docker compose down`.
- **Risk**: They are ONLY destroyed if explicitly removed via `docker volume rm` or a prune command.
- **NEVER** run `docker system prune` on this lab if you wish to keep your downloaded models.

## Log Locations
...
- **Agent Logs**: `~ ~/.openclaw/logs/<agent_name>/`

## Sandbox Tool Runner
The tool-runner is a Docker sandbox for executing Tier 1 tools without granting agents host execution privileges.

- Health: `curl -fsS http://localhost:18888/health`
- Notes:
  - Workspaces live at `~/.openclaw/workspaces/<agent>/group_<chat_id>/`.
  - Default policy denies internet egress (internal-only Docker network).
  - The sandbox never mounts `~/.openclaw/secrets`.
  - Requests require `SANDBOX_GUARD_TOKEN` (set in `~/.openclaw/.env`); `tools/sandbox_tool_run.json` sends it as `Authorization: Bearer ...`.

## 13. Google Calendar Setup
The calendar integration requires Google Cloud OAuth2 credentials.

### Initial Setup
1.  **Google Cloud Console**:
    - Enable the **Google Calendar API**.
    - Configure OAuth consent screen (Internal/External).
    - Create **OAuth 2.0 Client IDs** (Type: Desktop App).
2.  **Secret Placement**:
    - Download JSON credentials and save as `~/.openclaw/secrets/google_client_secret.json`.
    - Set permissions: `chmod 600 ~/.openclaw/secrets/google_client_secret.json`.
3.  **Authentication**:
    - Run the setup script to generate the token (not implemented yet, service handles 401).
    - Or manually place a valid `google_calendar_token.json` in `~/.openclaw/secrets/`.

### Troubleshooting
- **401 Unauthorized**: Ensure `google_client_secret.json` exists.
- **Timezone Mismatch**: Check host system set local timezone with `timedatectl`.
- **API Enablement**: Ensure "Google Calendar API" is enabled in GCP for the client ID used.

## 🧪 E2E Verification

Create an automated, repeatable verification flow that proves the entire system works.

### Running Tests Safely
- **Command**: `bash ~/.openclaw/tests/run_all_tests.sh`
- **Output**: Generates `~/.openclaw/docs/VERIFICATION_REPORT.md`.
- **Safety**: The suite uses isolated memory and non-destructive checks. It DOES NOT prune Docker or delete persistent volumes.

### Required Test Modules
The suite covers:
- Systemd status
- Environment & Permissions
- Telegram Allowlist integrity
- Agent Auth Sync
- Ollama & Model Visibility
- GPU Load & Acceleration
- OpenRouter & Google Providers
- Calendar & Dashboard Skill health
- RAG Pipeline End-to-End
- Memory Isolation & TTL Policies
