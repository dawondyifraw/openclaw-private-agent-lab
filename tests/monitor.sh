#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="/home/devbox/.openclaw"
OUTDIR="$ROOT/diagnostics"
OUT="$OUTDIR/context_overflow_report_${TS}.txt"

mkdir -p "$OUTDIR"

echo "OpenClaw Context Overflow Evidence Report" > "$OUT"
echo "Generated: $TS" >> "$OUT"
echo "Host: $(hostname)" >> "$OUT"
echo "User: $(whoami)" >> "$OUT"
echo "Live root: $ROOT" >> "$OUT"
echo "----------------------------------------" >> "$OUT"
echo >> "$OUT"

redact() {
  # Best-effort redaction for common key formats
  sed -E \
    -e 's/(sk-[A-Za-z0-9_-]{10,})/REDACTED_KEY/g' \
    -e 's/(gsk_[A-Za-z0-9_-]{10,})/REDACTED_KEY/g' \
    -e 's/(rk_[A-Za-z0-9_-]{10,})/REDACTED_KEY/g' \
    -e 's/(AIza[0-9A-Za-z\-_]{20,})/REDACTED_KEY/g' \
    -e 's/(OPENCLAW_GATEWAY_TOKEN=REDACTED \
    -e 's/("apiKey"\s*:\s*)".*?"/\1"REDACTED"/g'
}

section () {
  echo >> "$OUT"
  echo "## $1" >> "$OUT"
  echo "----------------------------------------" >> "$OUT"
}

cmd () {
  local title="$1"
  shift
  section "$title"
  echo "\$ $*" >> "$OUT"
  echo >> "$OUT"
  # shellcheck disable=SC2068
  ( $@ ) 2>&1 | redact >> "$OUT" || true
  echo >> "$OUT"
}

# 1) systemd status and recent logs
cmd "systemd: openclaw-gateway status" systemctl --user status openclaw-gateway --no-pager
cmd "systemd: openclaw-gateway last 15 minutes (raw)" journalctl --user -u openclaw-gateway --since "15 min ago" --no-pager
cmd "systemd: openclaw-gateway last 15 minutes (filtered tokens/compaction)" bash -lc \
  'journalctl --user -u openclaw-gateway --since "15 min ago" --no-pager | rg -n "context|token|compaction|reserve|reset|limit|truncate|overflow|notice" || true'

# 2) Config snapshots (redacted)
cmd "Config: openclaw.json (redacted preview)" bash -lc "sed -n '1,220p' $ROOT/openclaw.json | redact"
cmd "Config: main agent.yaml (redacted preview)" bash -lc "sed -n '1,260p' $ROOT/agents/main/agent/agent.yaml | redact"

# 3) Compaction setting extraction (best-effort)
cmd "Config: compaction fields (grep)" bash -lc \
  "rg -n \"compaction|reserveTokensFloor|maxTokens|contextWindow|truncate\" $ROOT/openclaw.json $ROOT/agents/*/agent/*.yaml 2>/dev/null || true"

# 4) Provider sanity (no keys printed)
cmd "Providers: openclaw models list (if available)" bash -lc "openclaw models list 2>/dev/null || true"

# 5) Docker support health (if present)
cmd "Docker: compose services (configured)" bash -lc "cd $ROOT && docker compose -f docker-compose.yml config --services"
cmd "Docker: running containers (names/images/ports)" bash -lc 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"'

# 6) RAG health (not required but useful)
cmd "RAG: health" bash -lc "curl -fsS http://localhost:8811/health || true"

# 7) Ollama context (if local used as fallback)
cmd "Ollama: tags" bash -lc "curl -fsS http://localhost:11434/api/tags || true"

# 8) Workspace and session hints
cmd "Workspace: root + recent dirs" bash -lc "ls -la $ROOT/workspaces && find $ROOT/workspaces -maxdepth 3 -type d | head -n 80"
cmd "Sessions: recent session files (agents/*/sessions)" bash -lc \
  "find $ROOT/agents -path '*/sessions/*' -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | sort -r | head -n 40"

echo "DONE: $OUT"
echo "Tip: Paste the report into analysis."
