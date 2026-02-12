#!/bin/bash
set -euo pipefail

# Configuration
OPENCLAW_ROOT="${OPENCLAW_ROOT:-$HOME/.openclaw}"
AGENTS_DIR="$OPENCLAW_ROOT/agents"
MAIN_AGENT_DIR="$AGENTS_DIR/main/agent"
AUTH_FILE="auth-profiles.json"
AUTH_TEMPLATE_FILE="$MAIN_AGENT_DIR/${AUTH_FILE}.example"
SOURCE_FILE="$MAIN_AGENT_DIR/$AUTH_FILE"
MODE="copy"
RESTART_GATEWAY="false"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode=copy|--copy)
            MODE="copy"
            shift
            ;;
        --mode=symlink|--symlink)
            MODE="symlink"
            shift
            ;;
        --restart)
            RESTART_GATEWAY="true"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--copy|--symlink] [--restart]"
            exit 1
            ;;
    esac
done

# Ensure source exists. If missing, bootstrap from the tracked template.
if [[ ! -f "$SOURCE_FILE" ]]; then
    if [[ -f "$AUTH_TEMPLATE_FILE" ]]; then
        log_warn "Missing $SOURCE_FILE. Bootstrapping from template $AUTH_TEMPLATE_FILE."
        cp "$AUTH_TEMPLATE_FILE" "$SOURCE_FILE"
    else
        log_error "Source auth file not found and no template available: $SOURCE_FILE"
        exit 1
    fi
fi

log_info "Syncing auth profiles from $SOURCE_FILE (mode=$MODE)..."

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

        if [[ "$MODE" == "symlink" ]]; then
            rm -f "$target_file"
            ln -s "$SOURCE_FILE" "$target_file"
            log_info "Symlinked auth to agent: $agent_name"
        else
            cp "$SOURCE_FILE" "$target_file"
            log_info "Copied auth to agent: $agent_name"
        fi
    fi
done

if [[ "$RESTART_GATEWAY" == "true" ]]; then
    log_info "Sync complete. Restarting gateway..."
    systemctl --user restart openclaw-gateway.service
    sleep 2
    systemctl --user status openclaw-gateway.service --no-pager
    log_info "Authentication profiles synced and gateway restarted."
else
    log_info "Authentication profiles synced."
fi
