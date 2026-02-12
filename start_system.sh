#!/bin/bash

# 1. Start Stage 2 Translation Service (Background)
echo "🚀 Starting Amharic Translation Service (Stage 2)..."
cd /home/devbox/.openclaw/services/amharic-translation
mkdir -p logs
nohup python3 amharic_translation_service.py > logs/service.log 2>&1 &
PID=$!
echo "✅ Translation Service running (PID: $PID)"
echo "   Logs: ~/.openclaw/services/amharic-translation/logs/service.log"

# 2. Start OpenClaw Gateway
echo "🚀 Starting OpenClaw Gateway..."
echo "   (Press Ctrl+C to stop)"
# Ensure auth profiles are consistent before gateway boot.
bash /home/devbox/.openclaw/scripts/sync_auth_profiles.sh --copy
openclaw gateway --force
