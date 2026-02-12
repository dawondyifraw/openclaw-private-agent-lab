#!/usr/bin/env bash
# OpenClaw QA preflight: safe bootstrap + readiness checks before gateway start.
# Intended for systemd ExecStartPre and manual runs.
set -euo pipefail

ROOT="/home/devbox/.openclaw"
ENV_FILE="${ROOT}/.env"
COMPOSE_FILE="${ROOT}/docker-compose.yml"
MODE="${OPENCLAW_TEST_MODE:-default}"
RUN_STRICT="${OPENCLAW_QA_PREFLIGHT_RUN_STRICT:-0}"
TIMEOUT_S="${OPENCLAW_QA_PREFLIGHT_TIMEOUT_S:-90}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "$*"; }
fail() { log "${RED}FAIL:${NC} $*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

wait_http() {
  local url="$1"
  local name="$2"
  local deadline=$((SECONDS + TIMEOUT_S))
  while (( SECONDS < deadline )); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      log "  ${GREEN}OK${NC} $name ($url)"
      return 0
    fi
    sleep 2
  done
  fail "$name did not become healthy within ${TIMEOUT_S}s ($url)"
}

log "=========================================================="
log "     OPENCLAW QA PREFLIGHT (BOOTSTRAP + READINESS)       "
log "=========================================================="
log "root: ${ROOT}"
log "mode: ${MODE}"

need_cmd docker
need_cmd curl
need_cmd bash

if [ -x "${ROOT}/scripts/patch_google_compat_failover.sh" ]; then
  log "Applying runtime compat failover patch..."
  bash "${ROOT}/scripts/patch_google_compat_failover.sh"
else
  log "${YELLOW}WARN:${NC} compat failover patch script missing or not executable"
fi

# Telegram runtime patches (split):
# - patch_telegram_sanitizer.sh: outbound sanitizer / leak suppressor rules
# - patch_telegram_command_allowlist.sh: slash-command default-deny + allowlist
#
# Backwards compat: if split scripts are missing, fall back to legacy combined script.
ran_split=0
if [ -x "${ROOT}/scripts/patch_telegram_sanitizer.sh" ]; then
  log "Applying Telegram sanitizer patch..."
  bash "${ROOT}/scripts/patch_telegram_sanitizer.sh"
  ran_split=1
fi
if [ -x "${ROOT}/scripts/patch_telegram_command_allowlist.sh" ]; then
  log "Applying Telegram command allowlist patch..."
  bash "${ROOT}/scripts/patch_telegram_command_allowlist.sh"
  ran_split=1
fi
if [ "$ran_split" = "0" ]; then
  if [ -x "${ROOT}/scripts/patch_telegram_reply_wrapper_sanitizer.sh" ]; then
    log "Applying legacy Telegram patch (reply-wrapper sanitizer)..."
    bash "${ROOT}/scripts/patch_telegram_reply_wrapper_sanitizer.sh"
  else
    log "${YELLOW}WARN:${NC} Telegram patch script missing or not executable"
  fi
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  fail "missing compose file: $COMPOSE_FILE"
fi
if [ ! -f "$ENV_FILE" ]; then
  fail "missing env file: $ENV_FILE"
fi

# Model profile sync is manual-by-design to avoid silent config overwrites.
if [ -x "${ROOT}/scripts/sync_model_profiles.sh" ]; then
  log "Model profile auto-sync is disabled (manual review required)."
  log "  Run manually if needed: ${ROOT}/scripts/sync_model_profiles.sh --apply"
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

log "Starting/refreshing support plane via docker compose..."
docker compose -f "$COMPOSE_FILE" up -d >/dev/null

log "Waiting for required service health endpoints..."
wait_http "http://localhost:11434/api/tags" "ollama"
wait_http "http://localhost:8000/api/v2/heartbeat" "chroma"
wait_http "http://localhost:8811/health" "rag-service"
wait_http "http://localhost:18790/health" "amharic-translation"
wait_http "http://localhost:18888/health" "sandbox-guard-proxy"

log "Checking required auth/env vars..."
required_vars=("GOOGLE_API_KEY" "OPENROUTER_API_KEY" "GROQ_API_KEY" "OPENCLAW_GATEWAY_TOKEN" "SANDBOX_GUARD_TOKEN" "TOOL_RUNNER_TOKEN")
for v in "${required_vars[@]}"; do
  if [ -z "${!v:-}" ]; then
    fail "required variable missing/empty in .env: $v"
  fi
  log "  ${GREEN}OK${NC} $v"
done

log "Checking recommended Ollama perf knobs..."
for kv in OLLAMA_NUM_PARALLEL OLLAMA_MAX_LOADED_MODELS OLLAMA_KEEP_ALIVE; do
  val="${!kv:-}"
  if [ -z "$val" ]; then
    log "  ${YELLOW}WARN${NC} ${kv} not set (recommended in .env.example)"
  else
    log "  ${GREEN}OK${NC} ${kv}=${val}"
  fi
done

if command -v nvidia-smi >/dev/null 2>&1; then
  log "GPU snapshot:"
  nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader | sed 's/^/  /'
else
  log "${YELLOW}WARN:${NC} nvidia-smi not found; GPU telemetry skipped"
fi

flash_state="$(docker logs ollama --tail 500 2>&1 | rg -i -m1 -N 'Flash Attention was auto, set to enabled|flash_attn\s*=\s*enabled|flash_attn\s*=\s*auto' || true)"
if [ -n "$flash_state" ]; then
  log "Flash-attention evidence:"
  log "  $flash_state"
else
  log "${YELLOW}WARN:${NC} no flash-attention evidence found in recent ollama logs (status unknown)"
fi

if [ "$RUN_STRICT" = "1" ]; then
  log "Running strict QA suite (OPENCLAW_TEST_MODE=strict)..."
  OPENCLAW_TEST_MODE=strict bash "${ROOT}/tests/run_all_tests.sh"
else
  log "Skipping strict QA suite (set OPENCLAW_QA_PREFLIGHT_RUN_STRICT=1 to enable)."
fi

log "${GREEN}PREFLIGHT PASS${NC}"
log "=========================================================="
