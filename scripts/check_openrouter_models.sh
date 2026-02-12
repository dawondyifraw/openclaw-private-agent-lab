#!/bin/bash
# scripts/check_openrouter_models.sh
# Queries OpenRouter for available models and recommends fallbacks.

set -e

ENV_FILE="/home/devbox/.openclaw/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found."
    exit 1
fi

OPENROUTER_API_KEY=$(grep "^OPENROUTER_API_KEY=" "$ENV_FILE" | cut -d '=' -f2)

if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "Error: OPENROUTER_API_KEY not set in .env"
    exit 1
fi

echo "Fetching models from OpenRouter..."
RESPONSE=$(curl -s -X GET "https://openrouter.ai/api/v1/models" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}")

if ! echo "$RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
    echo "Error: Invalid response from OpenRouter."
    exit 1
fi

echo "Available Models (Top 10):"
echo "$RESPONSE" | jq -r '.data[].id' | head -n 10
