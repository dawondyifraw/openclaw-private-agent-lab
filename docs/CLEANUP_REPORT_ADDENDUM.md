# Cleanup Report Addendum (Live Root v2)

**Date:** 2026-02-10  
**Live Root:** `/home/devbox/.openclaw`  
**Canonical workspaces root:** `/home/devbox/.openclaw/workspaces`  
**Compatibility alias:** `/home/devbox/.openclaw/workspace` -> `/home/devbox/.openclaw/workspaces`

## Change Summary (Non-Destructive)

Goal: remove legacy/backup folders from the live runtime tree (keep only in `/home/devbox/archives/`).

Moved out of live root:
- Old (live): `/home/devbox/.openclaw/workspaces/_legacy_workspace_backup`
- New (archive): `/home/devbox/archives/openclaw_legacy_2026-02-10/workspace_legacy/_legacy_workspace_backup`

Archive safety:
- Ensured the archive subtree is read-only:
  - `chmod -R a-w /home/devbox/archives/openclaw_legacy_2026-02-10/workspace_legacy`

Pointer for humans:
- Added `/home/devbox/.openclaw/workspaces/LEGACY_MOVED.md`

## Verification

1) No legacy backup folder remains in the live tree:
- `grep -R "_legacy_workspace_backup" /home/devbox/.openclaw || true`

2) Compatibility alias still resolves to canonical root:
- `readlink -f /home/devbox/.openclaw/workspace`
  - expected: `/home/devbox/.openclaw/workspaces`

3) Tests:
- `cd /home/devbox/.openclaw && bash tests/run_all_tests.sh`

