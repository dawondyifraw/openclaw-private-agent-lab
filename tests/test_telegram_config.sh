#!/bin/bash
# Telegram Configuration Validation Test
# Verifies that all groups have correct mention-only settings

CONFIG_FILE="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
PASS=0
FAIL=0

echo "=========================================="
echo "  Telegram Configuration Validation"
echo "=========================================="

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ FAIL: Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "✓ Config file found: $CONFIG_FILE"
echo

# Expected groups
EXPECTED_GROUPS=(
    "TG_GROUP_CODER_ID"
    "TG_GROUP_HELLO_ID"
    "TG_GROUP_ANXIETY_CHAT_ID"
    "TG_GROUP_MERRY_ID"
    "-1005251231014"
)

# Expected bindings
declare -A EXPECTED_BINDINGS
EXPECTED_BINDINGS["TG_GROUP_CODER_ID"]="g-coder"
EXPECTED_BINDINGS["TG_GROUP_HELLO_ID"]="g-hello"
EXPECTED_BINDINGS["TG_GROUP_ANXIETY_CHAT_ID"]="anxietychat"
EXPECTED_BINDINGS["TG_GROUP_MERRY_ID"]="merry-bot"
EXPECTED_BINDINGS["-1005251231014"]="assistant"

echo "=== Test 1: requireMention=true for all groups ==="
for group in "${EXPECTED_GROUPS[@]}"; do
    require_mention=$(jq -r ".channels.telegram.groups.\"$group\".requireMention // false" "$CONFIG_FILE")
    
    if [ "$require_mention" = "true" ]; then
        echo "✓ PASS: Group $group has requireMention=true"
        ((PASS++))
    else
        echo "❌ FAIL: Group $group has requireMention=$require_mention (expected true)"
        ((FAIL++))
    fi
done
echo

echo "=== Test 2: Group allowlist configuration ==="
group_policy=$(jq -r '.channels.telegram.groupPolicy // "none"' "$CONFIG_FILE")
if [ "$group_policy" = "allowlist" ]; then
    echo "✓ PASS: groupPolicy is 'allowlist'"
    ((PASS++))
else
    echo "❌ FAIL: groupPolicy is '$group_policy' (expected 'allowlist')"
    ((FAIL++))
fi

for group in "${EXPECTED_GROUPS[@]}"; do
    in_allowlist=$(jq -r ".channels.telegram.groupAllowFrom | map(select(. == \"$group\")) | length" "$CONFIG_FILE")
    
    if [ "$in_allowlist" -gt 0 ]; then
        echo "✓ PASS: Group $group is in allowlist"
        ((PASS++))
    else
        echo "❌ FAIL: Group $group is NOT in allowlist"
        ((FAIL++))
    fi
done
echo

echo "=== Test 3: Agent bindings ==="
for group in "${EXPECTED_GROUPS[@]}"; do
    expected_agent="${EXPECTED_BINDINGS[$group]}"
    actual_agent=$(jq -r ".bindings[] | select(.match.channel == \"telegram\" and .match.peer.id == \"$group\") | .agentId" "$CONFIG_FILE")
    
    if [ "$actual_agent" = "$expected_agent" ]; then
        echo "✓ PASS: Group $group → $actual_agent"
        ((PASS++))
    else
        echo "❌ FAIL: Group $group → $actual_agent (expected $expected_agent)"
        ((FAIL++))
    fi
done
echo

echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi

exit 0
