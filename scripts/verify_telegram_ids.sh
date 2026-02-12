#!/bin/bash
# verify_telegram_ids.sh

# Load environment variables
if [ -f "/home/devbox/.openclaw/.env" ]; then
    export $(grep -v '^#' /home/devbox/.openclaw/.env | xargs)
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "[Error] TELEGRAM_BOT_TOKEN is missing."
    exit 1
fi

CHECK_IDS=("TG_GROUP_HELLO_ID" "TG_GROUP_MERRY_ID" "TG_GROUP_CODER_ID" "TG_GROUP_ANXIETY_CHAT_ID" "-1005251231014" "5251231014")

echo "| Group Name | Raw Telegram chat.id | Stored ID string | Status |"
echo "|------------|----------------------|------------------|--------|"

for ID in "${CHECK_IDS[@]}"; do
    RESPONSE=$(curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getChat?chat_id=$ID")
    OK=$(echo "$RESPONSE" | jq -r '.ok')
    
    if [ "$OK" == "true" ]; then
        CHAT_NAME=$(echo "$RESPONSE" | jq -r '.result.title // .result.first_name // "Unknown"')
        RAW_ID=$(echo "$RESPONSE" | jq -r '.result.id')
        
        # Check if RAW_ID matches expected ID
        STATUS="VALID"
        if [ "$RAW_ID" != "$ID" ]; then
            STATUS="MISMATCH!"
        fi
        
        printf "| %-10s | %-20s | %-16s | %-6s |\n" "$CHAT_NAME" "$RAW_ID" "$ID" "$STATUS"
    else
        # If ID failed, it might be the short version vs long version
        printf "| %-10s | %-20s | %-16s | %-6s |\n" "FAILED" "N/A" "$ID" "NOT_FOUND"
    fi
done

echo ""
echo "[Updates Check] Fetching last 5 updates..."
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates?limit=5" | jq -r '.result[] | "Update ID: \(.update_id) | Chat ID: \(.message.chat.id // .my_chat_member.chat.id) | Title: \(.message.chat.title // .my_chat_member.chat.title)"'
