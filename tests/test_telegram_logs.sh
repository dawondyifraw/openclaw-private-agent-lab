#!/bin/bash
# Telegram Log Analysis Test
# Analyzes recent GATE_DEBUG logs to verify mention-only behavior

PASS=0
FAIL=0
WARN=0

echo "=========================================="
echo "  Telegram Log Analysis"
echo "=========================================="

MODE="${OPENCLAW_TEST_MODE:-default}"

# Get recent GATE_DEBUG logs (last 100 lines)
LOGS=$(journalctl --user -u openclaw-gateway -n 100 --no-pager 2>/dev/null | grep "GATE_DEBUG" || echo "")

if [ -z "$LOGS" ]; then
    echo "⚠️  WARNING: No GATE_DEBUG logs found in recent activity"
    echo "   This test requires recent Telegram activity to analyze."
    echo "   Please send some test messages in Telegram groups and re-run."
    echo "STRICT MODE NOTE: config-only validation covers allowlist/bindings; log-based behavior requires live traffic."
    exit 0
fi

echo "Found $(echo "$LOGS" | wc -l) GATE_DEBUG log entries"
echo

echo "=== Test 1: requireMention enforcement ==="
# Count logs with requireMention:true vs false
require_true=$(echo "$LOGS" | grep -o '"requireMention":true' | wc -l)
require_false=$(echo "$LOGS" | grep -o '"requireMention":false' | wc -l)

echo "  requireMention:true  = $require_true"
echo "  requireMention:false = $require_false"

if [ $require_true -gt 0 ] && [ $require_false -eq 0 ]; then
    echo "✓ PASS: All recent logs show requireMention:true"
    ((PASS++))
elif [ $require_false -gt 0 ]; then
    echo "❌ FAIL: Found $require_false logs with requireMention:false (config may not be applied)"
    ((FAIL++))
else
    echo "⚠️  WARN: No logs found (need recent activity)"
    ((WARN++))
fi
echo

echo "=== Test 2: Main agent silence in bound groups ==="
# Check if main agent appears in logs for bound groups
main_in_groups=$(echo "$LOGS" | grep '"selectedAgent":"main"' | grep -E '(TG_GROUP_CODER_ID|TG_GROUP_HELLO_ID|TG_GROUP_ANXIETY_CHAT_ID|TG_GROUP_MERRY_ID|-1005251231014)' | wc -l)

if [ $main_in_groups -eq 0 ]; then
    echo "✓ PASS: Main agent not selected in any bound group"
    ((PASS++))
else
    echo "❌ FAIL: Main agent selected $main_in_groups times in bound groups"
    ((FAIL++))
fi
echo

echo "=== Test 3: Mention detection working ==="
# Check for mention detection
mentions_detected=$(echo "$LOGS" | grep '"isMention":true' | wc -l)
no_mentions=$(echo "$LOGS" | grep '"isMention":false' | wc -l)

echo "  Mentions detected: $mentions_detected"
echo "  Non-mentions: $no_mentions"

if [ $mentions_detected -gt 0 ]; then
    echo "✓ PASS: Mention detection is working"
    ((PASS++))
else
    echo "⚠️  WARN: No mentions detected in recent logs (send @moltbotd_bot test)"
    ((WARN++))
fi
echo

echo "=== Test 4: Correct agent routing ==="
# Verify each group routes to correct agent
declare -A EXPECTED_AGENTS
EXPECTED_AGENTS["TG_GROUP_CODER_ID"]="g-coder"
EXPECTED_AGENTS["TG_GROUP_HELLO_ID"]="g-hello"
EXPECTED_AGENTS["TG_GROUP_ANXIETY_CHAT_ID"]="anxietychat"
EXPECTED_AGENTS["TG_GROUP_MERRY_ID"]="merry-bot"
EXPECTED_AGENTS["-1005251231014"]="assistant"

for group in "${!EXPECTED_AGENTS[@]}"; do
    expected="${EXPECTED_AGENTS[$group]}"
    wrong_agent=$(echo "$LOGS" | grep "\"chatId\":$group" | grep -v "\"selectedAgent\":\"$expected\"" | wc -l)
    
    if [ $wrong_agent -eq 0 ]; then
        echo "✓ PASS: Group $group routes to $expected"
        ((PASS++))
    else
        echo "❌ FAIL: Group $group has $wrong_agent incorrect routing(s)"
        ((FAIL++))
    fi
done
echo

echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "=========================================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi

exit 0
