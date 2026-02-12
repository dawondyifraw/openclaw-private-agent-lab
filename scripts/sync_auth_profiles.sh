#!/bin/bash
set -e

# Configuration
AGENTS_DIR="$HOME/.openclaw/agents"
MAIN_AGENT_DIR="$AGENTS_DIR/main/agent"
AUTH_FILE="auth-profiles.json"
SOURCE_FILE="$MAIN_AGENT_DIR/$AUTH_FILE"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check source file
if [[ ! -f "$SOURCE_FILE" ]]; then
    log_error "Source auth file not found: $SOURCE_FILE"
    exit 1
fi

log_info "Syncing auth profiles from $SOURCE_FILE..."

# Iterate over all directories in agents dir
for agent_path in "$AGENTS_DIR"/*; do
    if [[ -d "$agent_path" ]]; then
        agent_name=$(basename "$agent_path")
        
        # Skip main agent
        if [[ "$agent_name" == "main" ]]; then
            continue
        fi

        target_agent_dir="$agent_path/agent"
        target_file="$target_agent_dir/$AUTH_FILE"

        # Create agent dir if missing (shouldn't happen for active agents but good safety)
        if [[ ! -d "$target_agent_dir" ]]; then
            log_warn "Agent config directory missing for $agent_name, creating..."
            mkdir -p "$target_agent_dir"
        fi

        # Copy file
        cp "$SOURCE_FILE" "$target_file"
        log_info "Synced auth to agent: $agent_name"
    fi
done

log_info "Sync complete. Restarting gateway to apply changes..."
systemctl --user restart openclaw-gateway.service

# Wait for service to be active
log_info "Waiting for gateway to restart..."
sleep 5
systemctl --user status openclaw-gateway.service --no-pager

log_info "Authentication profiles synced and gateway restarted."
