# Workspace Layout Report (workspace vs workspaces)

**Date:** 2026-02-10  
**Live root:** `/home/devbox/.openclaw`  
**Canonical workspace root (target):** `/home/devbox/.openclaw/workspaces`

## Why There Were Two

- `/home/devbox/.openclaw/workspace` (singular) existed as a legacy scaffold containing agent-named folders and docs.
- `/home/devbox/.openclaw/workspaces` (plural) is used by the sandbox tool-runner design for per-agent, per-scope workspaces:
  - `workspaces/<agent>/group_<chat_id>/...`

## Evidence (Before Change)

References to singular path:
- `tests/verify_system_hardening.sh` checked:
  - `/home/devbox/.openclaw/workspace/agents/<agent>/auth-profiles.json`

References to plural path:
- `tests/test_sandbox_runner.sh` prepared workspaces under:
  - `/home/devbox/.openclaw/workspaces`
- `docker-compose.yml` and tool-runner config used:
  - `HOST_WORKSPACES_ROOT=/home/devbox/.openclaw/workspaces`

## What Changed

1. Canonical root is now **plural**:
   - `OPENCLAW_WORKSPACES_ROOT=/home/devbox/.openclaw/workspaces` (exported by `tests/run_all_tests.sh`)
2. Legacy singular references removed from tests:
   - `tests/verify_system_hardening.sh` now checks auth profiles under:
     - `/home/devbox/.openclaw/agents/<agent>/agent/auth-profiles.json`
3. Compatibility layer enforced:
   - `/home/devbox/.openclaw/workspace` becomes a compatibility path that resolves to the canonical root.
4. Legacy contents preserved (non-destructive):
   - Previous contents of `/home/devbox/.openclaw/workspace/` were moved to:
     - `/home/devbox/.openclaw/workspaces/_legacy_workspace_backup/`

## How To Verify

```bash
readlink -f /home/devbox/.openclaw/workspace
readlink -f /home/devbox/.openclaw/workspaces
```

The two outputs should match.

Test:
```bash
cd /home/devbox/.openclaw && bash tests/test_workspace_root.sh
```
