# Telegram E2E Verification Guide

## Overview

This document describes the Telegram mention-only behavior specification and verification procedures for OpenClaw.

## Baseline Behavior (Plan D)

**Mention-Only Policy:**
- **ALL agents** in groups require explicit mentions to respond
- **NO responses** to plain messages without mentions
- Accepted mentions: `@moltbotd_bot` (bot username)
- Commands without mentions: **NO response** (mention required for all interactions)

## Group Bindings

| Group ID | Agent | Purpose |
|----------|-------|---------|
| `TG_GROUP_CODER_ID` | `g-coder` | Coding assistance |
| `TG_GROUP_HELLO_ID` | `g-hello` | Haymi (Lovely) - Amharic |
| `TG_GROUP_ANXIETY_CHAT_ID` | `anxietychat` | Anxiety support |
| `TG_GROUP_MERRY_ID` | `merry-bot` | Merry - Amharic |
| `-1005251231014` | `assistant` | Dashboard management |

**Main agent:** Default fallback, but **must NOT respond** in bound groups unless explicitly mentioned.

## Configuration

All groups have `requireMention: true`:

```json
"channels": {
  "telegram": {
    "groupPolicy": "allowlist",
    "groups": {
      "TG_GROUP_CODER_ID": {"requireMention": true},
      "TG_GROUP_HELLO_ID": {"requireMention": true},
      "TG_GROUP_ANXIETY_CHAT_ID": {"requireMention": true},
      "TG_GROUP_MERRY_ID": {"requireMention": true},
      "-1005251231014": {"requireMention": true}
    }
  }
}
```

## Automated Tests

### 1. Configuration Validation (`test_telegram_config.sh`)

Verifies:
- ✅ All 5 groups have `requireMention: true`
- ✅ `groupPolicy: allowlist` is set
- ✅ All groups are in allowlist
- ✅ Agent bindings are correct

**Run:** `./tests/test_telegram_config.sh`

### 2. Log Analysis (`test_telegram_logs.sh`)

Analyzes recent `GATE_DEBUG` logs to verify:
- ✅ `requireMention: true` in all recent logs
- ✅ Main agent not selected in bound groups
- ✅ Mention detection working (`isMention: true`)
- ✅ Correct agent routing per group

**Run:** `./tests/test_telegram_logs.sh`

**Note:** Requires recent Telegram activity to analyze.

## Manual Verification

For complete E2E proof, perform these manual tests in each group:

### Test 1: Non-Mention Message (Expect: NO REPLY)
```
Send: "hello"
Expected: Bot stays silent
Log: {"isMention":false,"reason":"none","requireMention":true}
```

### Test 2: Mention Message (Expect: REPLY from bound agent)
```
Send: "@moltbotd_bot hello"
Expected: Reply from the bound agent for that group
Log: {"isMention":true,"reason":"mention","selectedAgent":"<bound-agent>"}
```

### Test 3: Command Without Mention (Expect: NO REPLY)
```
Send: "/status"
Expected: Bot stays silent
Log: {"isMention":false,"reason":"none"}
```

### Test 4: Command With Mention (Expect: REPLY)
```
Send: "@moltbotd_bot /status"
Expected: Status reply from bound agent
Log: {"isMention":true,"reason":"mention"}
```

## Monitoring

### Real-Time Log Monitoring
```bash
journalctl --user -u openclaw-gateway -f | grep GATE_DEBUG
```

### Recent Activity Analysis
```bash
journalctl --user -u openclaw-gateway -n 100 --no-pager | grep GATE_DEBUG | jq .
```

## Troubleshooting

### Bot Responds Without Mention
1. Check config: `jq '.channels.telegram.groups' ~/.openclaw/openclaw.json`
2. Verify `requireMention: true` for the group
3. Restart gateway: `systemctl --user restart openclaw-gateway`
4. Check logs for `"requireMention":false` (indicates old config)

### Main Agent Responding in Bound Groups
1. Check bindings: `jq '.bindings' ~/.openclaw/openclaw.json`
2. Verify group has correct agent binding
3. Check logs for `"selectedAgent":"main"` in bound groups
4. Review gating logic in `dist/reply-B_4pVbIX.js` (lines 36531-36555)

### Mention Not Detected
1. Verify bot username: `@moltbotd_bot`
2. Check logs for `"isMention":false` when mentioned
3. Ensure mention is at start or includes @ symbol
4. Test with explicit mention: `@moltbotd_bot test`

## Integration with CI

The Telegram tests are integrated into `tests/run_all_tests.sh`:
```bash
cd /home/devbox/.openclaw
./tests/run_all_tests.sh
```

Tests 13-14 cover Telegram:
- Test 13: Telegram Config (configuration validation)
- Test 14: Telegram Behavior (log analysis)

## Switching to Always-On (Optional)

To disable mention requirement for a specific group:

```json
"groups": {
  "TG_GROUP_CODER_ID": {
    "requireMention": false  // Bot responds to all messages
  }
}
```

**Warning:** This will cause the bot to respond to every message in that group. The main agent gating logic will still prevent `main` from responding in bound groups.
