# OpenClaw Home Lab Runbook

## Operational Commands

### Start System
```bash
# Start support services
docker compose -f ~/.openclaw/docker-compose.yml up -d

# Start OpenClaw gateway
systemctl --user start openclaw-gateway.service
```

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
- **Gateway**: `journalctl --user -u openclaw-gateway.service`
- **Support Services**: `docker logs <container_name>`
- **Agent Logs**: `~/.openclaw/logs/<agent_name>/`

## Maintenance
- **Rebuild Index**:
  ```bash
  docker compose down
  docker volume rm openclaw_chroma_data
  docker compose up -d
  # Follow with document ingestion
  ```
