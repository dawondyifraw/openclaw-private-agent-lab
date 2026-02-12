# OpenClaw System Verification Report
**Date:** Tue Feb 10 01:09:55 CET 2026
**System Version:** 2026.2.6-3

## Summary Results
| Module | Status | Details |
|--------|--------|---------|

### Evidence: Systemd
```
Checking openclaw-gateway.service... [0;32mPASS[0m
```

### Evidence: Environment
```
Checking environment variables...
  GOOGLE_API_KEY: [0;32mEXISTS[0m
  GROQ_API_KEY: [0;32mEXISTS[0m
  OPENROUTER_API_KEY: [0;32mEXISTS[0m
  KIMI_API_KEY: [0;32mEXISTS[0m
Checking secrets directory permissions... [0;32mPASS (700)[0m
```

### Evidence: Telegram Allowlist
```
Checking Telegram groupPolicy... [0;32mPASS (allowlist)[0m
Verifying required Group IDs in groupAllowFrom...
  TG_GROUP_CODER_ID: [0;32mOK[0m
  TG_GROUP_HELLO_ID: [0;32mOK[0m
  TG_GROUP_ANXIETY_CHAT_ID: [0;32mOK[0m
  TG_GROUP_MERRY_ID: [0;32mOK[0m
  -1005251231014: [0;32mOK[0m
```

### Evidence: Agent Auth Sync
```
Checking agent auth profiles...
  main: [0;32mFOUND[0m
    [Ollama Auth: api_key]
  anxietychat: [0;32mFOUND[0m
    [Ollama Auth: api_key]
  assistant: [0;32mFOUND[0m
    [Ollama Auth: api_key]
  g-coder: [0;32mFOUND[0m
    [Ollama Auth: api_key]
  g-hello: [0;32mFOUND[0m
    [Ollama Auth: api_key]
  merry-bot: [0;32mFOUND[0m
    [Ollama Auth: api_key]
```

### Evidence: Ollama Local
```
Checking Ollama connectivity... [0;32mPASS[0m
Checking required models...
  qwen2.5:14b: [0;32mOK[0m
  qwen2.5-coder:14b: [0;32mOK[0m
  mistral-nemo:12b: [0;32mOK[0m
  dolphin3:8b: [0;32mOK[0m
```

### Evidence: GPU Utilization
```
Checking nvidia-smi visibility... [0;32mPASS[0m
Verifying GPU utilization under load...
  Utilization Before: 23%
  Utilization During: 26%
[0;32mPASS[0m (Utilization increased)
```

### Evidence: OpenRouter Provider
```
Checking OpenRouter connectivity... [0;32mPASS[0m
Checking for cognitivecomputations/dolphin-mixtral-8x22b... [0;31mUNAVAILABLE[0m
Detecting fallback models...
Recommended fallback: ai21/jamba-large-1.7
```

### Evidence: Google Provider
```
Validating Google API Key... [0;32mVALID[0m
```

### Evidence: Calendar Service
```
Checking Calendar service on port 18821... [0;32mPASS[0m
Checking OAuth token file permissions... SKIP (Token not yet authorized)
```

### Evidence: RAG Pipeline
```
Checking RAG-service health... [0;32mPASS[0m
Verifying RAG ingestion and retrieval...
  Ingestion: [0;32mOK[0m
  Retrieval: [0;32mOK[0m
```

### Evidence: Dashboard Skill
```
Checking Dashboard storage... [0;32mWRITABLE[0m
Verifying JSON integrity for existing data...
  -1005251231014.json: [0;32mOK[0m
```

### Evidence: Memory Isolation
```
Verifying memory path existence and isolation...
  main memory path: [0;32mEXISTS[0m
  anxietychat memory path: [0;32mEXISTS[0m
  assistant memory path: SKIP (Not created yet)
  g-coder memory path: [0;32mEXISTS[0m
  g-hello memory path: [0;32mEXISTS[0m
  merry-bot memory path: [0;32mEXISTS[0m
Checking cross-agent isolation... [0;32mCONFIGURED[0m
Checking TTL for anxietychat... WARNING (TTL not found in anxietychat config)[0m
```

### Evidence: Telegram Config
```
==========================================
  Telegram Configuration Validation
==========================================
✓ Config file found: /home/devbox/.openclaw/openclaw.json

=== Test 1: requireMention=true for all groups ===
✓ PASS: Group TG_GROUP_CODER_ID has requireMention=true
✓ PASS: Group TG_GROUP_HELLO_ID has requireMention=true
✓ PASS: Group TG_GROUP_ANXIETY_CHAT_ID has requireMention=true
✓ PASS: Group TG_GROUP_MERRY_ID has requireMention=true
✓ PASS: Group -1005251231014 has requireMention=true

=== Test 2: Group allowlist configuration ===
✓ PASS: groupPolicy is 'allowlist'
✓ PASS: Group TG_GROUP_CODER_ID is in allowlist
✓ PASS: Group TG_GROUP_HELLO_ID is in allowlist
✓ PASS: Group TG_GROUP_ANXIETY_CHAT_ID is in allowlist
✓ PASS: Group TG_GROUP_MERRY_ID is in allowlist
✓ PASS: Group -1005251231014 is in allowlist

=== Test 3: Agent bindings ===
✓ PASS: Group TG_GROUP_CODER_ID → g-coder
✓ PASS: Group TG_GROUP_HELLO_ID → g-hello
✓ PASS: Group TG_GROUP_ANXIETY_CHAT_ID → anxietychat
✓ PASS: Group TG_GROUP_MERRY_ID → merry-bot
✓ PASS: Group -1005251231014 → assistant

==========================================
  Results: 16 passed, 0 failed
==========================================
```

### Evidence: Telegram Behavior
```
==========================================
  Telegram Log Analysis
==========================================
Found 4 GATE_DEBUG log entries

=== Test 1: requireMention enforcement ===
  requireMention:true  = 4
  requireMention:false = 0
✓ PASS: All recent logs show requireMention:true

=== Test 2: Main agent silence in bound groups ===
✓ PASS: Main agent not selected in any bound group

=== Test 3: Mention detection working ===
  Mentions detected: 1
  Non-mentions: 3
✓ PASS: Mention detection is working

=== Test 4: Correct agent routing ===
✓ PASS: Group TG_GROUP_HELLO_ID routes to g-hello
✓ PASS: Group TG_GROUP_MERRY_ID routes to merry-bot
✓ PASS: Group -1005251231014 routes to assistant
✓ PASS: Group TG_GROUP_CODER_ID routes to g-coder
✓ PASS: Group TG_GROUP_ANXIETY_CHAT_ID routes to anxietychat

==========================================
  Results: 8 passed, 0 failed, 0 warnings
==========================================
```
| Systemd | PASS | - |
| Environment | PASS | - |
| Telegram Allowlist | PASS | - |
| Agent Auth Sync | PASS | - |
| Ollama Local | PASS | - |
| GPU Utilization | PASS | - |
| OpenRouter Provider | PASS | - |
| Google Provider | PASS | - |
| Calendar Service | PASS | - |
| RAG Pipeline | PASS | - |
| Dashboard Skill | PASS | - |
| Memory Isolation | PASS | - |
| Telegram Config | PASS | - |
| Telegram Behavior | PASS | - |


## Manual Checklist
- [ ] Send 'hello' in Group TG_GROUP_HELLO_ID (Haymi) -> Response in Amharic?
- [ ] Send '@main /cal next' in Dashboard Group -> Event list shown?
- [ ] Send '/task add Test' in Dashboard Group -> Task ID returned?
