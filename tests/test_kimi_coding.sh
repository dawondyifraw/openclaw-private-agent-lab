#!/bin/bash
# tests/test_kimi_coding.sh

KIMI_API_KEY=$(grep "^KIMI_API_KEY=" /home/devbox/.openclaw/.env | cut -d'=' -f2)

if [ -z "$KIMI_API_KEY" ]; then
    echo "KIMI_API_KEY not found in .env"
    exit 1
fi

echo "Validating Kimi API Key..."
curl -s -o /dev/null -w "%{http_code}" -X POST "https://api.moonshot.cn/v1/chat/completions" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $KIMI_API_KEY" \
     -d '{
       "model": "moonshot-v1-8k",
       "messages": [{"role": "user", "content": "hi"}]
     }' | grep -q "200"

if [ $? -eq 0 ]; then
    echo "Kimi API: VALID (200)"
else
    echo "Kimi API: FAILED"
    # Show detail
    curl -i -X POST "https://api.moonshot.cn/v1/chat/completions" \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer $KIMI_API_KEY" \
         -d '{
           "model": "moonshot-v1-8k",
           "messages": [{"role": "user", "content": "hi"}]
         }'
fi
