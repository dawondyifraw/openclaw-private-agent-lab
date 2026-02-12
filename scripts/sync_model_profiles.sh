#!/bin/bash
set -euo pipefail

# Sync agent model configs from main to every other agent.
# Keeps provider/model definitions aligned across agents.

AGENTS_DIR="$HOME/.openclaw/agents"
MAIN_AGENT_DIR="$AGENTS_DIR/main/agent"
MODELS_FILE="models.json"
SOURCE_FILE="$MAIN_AGENT_DIR/$MODELS_FILE"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
elif [[ -n "${1:-}" ]]; then
  log_error "Unsupported argument: $1"
  echo "Usage: $0 [--apply]"
  exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  log_error "Source models file not found: $SOURCE_FILE"
  exit 1
fi

if [[ "$APPLY" -eq 1 ]]; then
  log_info "Applying model profile sync from $SOURCE_FILE..."
else
  log_warn "Dry-run mode. No files will be changed."
  log_info "Planned model profile sync from $SOURCE_FILE:"
fi

for agent_path in "$AGENTS_DIR"/*; do
  if [[ ! -d "$agent_path" ]]; then
    continue
  fi

  agent_name=$(basename "$agent_path")
  if [[ "$agent_name" == "main" ]]; then
    continue
  fi

  target_agent_dir="$agent_path/agent"
  target_file="$target_agent_dir/$MODELS_FILE"

  if [[ ! -d "$target_agent_dir" ]]; then
    if [[ "$APPLY" -eq 1 ]]; then
      log_warn "Agent config directory missing for $agent_name, creating..."
      mkdir -p "$target_agent_dir"
    else
      log_warn "Would create missing directory for $agent_name: $target_agent_dir"
    fi
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    cp "$SOURCE_FILE" "$target_file"
    log_info "Synced models to agent: $agent_name"
  else
    if [[ -f "$target_file" ]]; then
      if cmp -s "$SOURCE_FILE" "$target_file"; then
        log_info "Would sync models to agent: $agent_name (already identical)"
      else
        log_info "Would sync models to agent: $agent_name (changes detected)"
      fi
    else
      log_info "Would sync models to agent: $agent_name (target missing)"
    fi
  fi
done

if [[ "$APPLY" -eq 1 ]]; then
  log_info "Model profile sync complete."
else
  log_info "Dry-run complete. Re-run with --apply to write changes."
fi
