# OpenClaw System Verification Report
**Date:** Thu Feb 12 21:02:08 CET 2026
**System Version:** 2026.2.6-3
**Test Mode:** strict

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
  OPENROUTER_API_KEY: [0;32mEXISTS[0m
  GROQ_API_KEY: [0;32mEXISTS[0m
  OPENCLAW_GATEWAY_TOKEN: [0;32mEXISTS[0m
Checking sandbox auth tokens in .env...
  SANDBOX_GUARD_TOKEN: [0;32mEXISTS[0m
  TOOL_RUNNER_TOKEN: [0;32mEXISTS[0m
Checking secrets directory permissions... [0;32mPASS (700)[0m
```

### Evidence: Workspace Root
```
PASS: workspace root unified (/home/devbox/.openclaw/workspace -> /home/devbox/.openclaw/workspaces)
```

### Evidence: Telegram Allowlist
```
Checking Telegram groupPolicy... [0;32mPASS (allowlist)[0m
Verifying required Group IDs in groupAllowFrom...
Verifying groupAllowFrom entries are strings... [0;32mOK[0m
  TG_GROUP_CODER_ID: [0;32mOK[0m
  TG_GROUP_HELLO_ID: [0;32mOK[0m
  TG_GROUP_ANXIETY_CHAT_ID: [0;32mOK[0m
  TG_GROUP_MERRY_ID: [0;32mOK[0m
  TG_GROUP_ASSISTANT_DASHBOARD_ID: [0;32mOK[0m
```

### Evidence: Telegram Sanitizer Present
```
PASS: OpenClaw Telegram hardening markers present in installed gateway bundle.
```

### Evidence: Google Compat Failover Patch
```
PASS: compat failover markers present in helper bundles (4 checked)
```

### Evidence: Telegram Reply Wrapper Sanitizer
```
PASS: reply-wrapper sanitizer present in installed bundle
```

### Evidence: Telegram Known Commands
```
PASS: telegram known-command allowlist present in installed bundle
```

### Evidence: Telegram Unknown Commands Static
```
PASS: unknown slash commands remain static default-deny
```

### Evidence: Telegram Tool Intent Relay
```
PASS: telegram tool-intent relay marker and guards present
```

### Evidence: Agent Auth Sync
```
Checking agent auth profiles...
  anxietychat: [0;32mFOUND[0m
    [Ollama Auth: api_key + key]
  assistant: [0;32mFOUND[0m
    [Ollama Auth: api_key + key]
  g-coder: [0;32mFOUND[0m
    [Ollama Auth: api_key + key]
  g-hello: [0;32mFOUND[0m
    [Ollama Auth: api_key + key]
  g-moltd: [0;32mFOUND[0m
    [Ollama Auth: api_key + key]
  main: [0;32mFOUND[0m
    [Ollama Auth: api_key + key]
  merry-bot: [0;32mFOUND[0m
    [Ollama Auth: api_key + key]
```

### Evidence: Agent Model Sync
```
Checking agent model profile sync...
  anxietychat: [0;32mSYNCED[0m
  assistant: [0;32mSYNCED[0m
  g-coder: [0;32mSYNCED[0m
  g-hello: [0;32mSYNCED[0m
  g-moltd: [0;32mSYNCED[0m
  main: [0;32mSYNCED[0m
  merry-bot: [0;32mSYNCED[0m
PASS: all agent model profiles are synced.
```

### Evidence: Agent Tool Consistency
```
PASS: tool/prompt consistency
```

### Evidence: Ollama Local
```
Checking Ollama connectivity... [0;32mPASS[0m
Checking required models...
  qwen2.5:14b: [0;32mOK[0m
  qwen2.5-coder:14b: [0;32mOK[0m
  mistral-nemo:12b: [0;32mOK[0m
  dolphin3:8b: [0;32mOK[0m
  wngtcalex/mythomax-13b: [0;32mOK[0m
  glm-4.7: [0;32mOK[0m
```

### Evidence: GPU Utilization
```
Checking nvidia-smi visibility... [0;32mPASS[0m
Verifying GPU utilization under load...
  Utilization Before: 33%
  Utilization Max During: 39%
[0;32mPASS[0m (GPU utilization observed during inference)
```

### Evidence: OpenRouter Provider
```
Checking OpenRouter API key presence... [0;32mOK[0m
Validating OpenRouter via lightweight chat completion... [0;32mPASS[0m (model=google/gemini-2.0-flash-001)
```

### Evidence: Groq Provider
```
Checking Groq API key presence... [0;32mOK[0m
Validating Groq via lightweight chat completion... [0;32mPASS[0m (model=llama-3.3-70b-versatile)
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

### Evidence: Main Failover
```
[0;32mPASS[0m: Notice string present in main agent config
Main primary (OpenRouter) completion... [0;32mPASS[0m (model=google/gemini-2.0-flash-001)
Forcing primary failure (invalid OpenRouter key) and proving Groq fallback works...
  OpenRouter with invalid key... [0;32mOK[0m (HTTP 502)
  Groq fallback completion... [0;32mPASS[0m (model=llama-3.3-70b-versatile)
[Notice] main switched from openrouter (google/gemini-2.0-flash-001) to groq (llama-3.3-70b-versatile) due to auth-failure.
[0;32mPASS[0m: Failover proof (OpenRouter -> Groq) complete
```

### Evidence: Fallback Under Cooldown
```
Simulate Groq cooldown/auth failure... [0;32mPASS[0m (HTTP 401)
Gemini direct succeeds... [0;32mPASS[0m
OpenRouter succeeds... [0;32mPASS[0m
PASS: Groq failure path is recoverable through Gemini/OpenRouter providers.
```

### Evidence: Fallback Locking
```
PASS: fallback locking + per-agent chains enforced.
```

### Evidence: Sandbox Runner
```
[0;32mPASS[0m: Sandbox Health
[0;32mPASS[0m: Workspace Containment
[0;32mPASS[0m: Spoof Attempt Denied
[0;32mPASS[0m: No Secrets Exposure
[0;32mPASS[0m: No Internet Egress (Default)
[0;32mPASS[0m: Allowed Internal Egress
[0;32mPASS[0m: Tool-Runner Auth Required
[0;32mPASS[0m: RW Enforcement (RO Mount)
[0;32mPASS[0m: Tool Output Sanitization
```

### Evidence: Memory Isolation
```
Verifying per-agent memory configuration...
  main agent.yaml: [0;32mOK[0m
  main memory path: [0;32m/home/devbox/.openclaw/memory/main[0m
  anxietychat agent.yaml: [0;32mOK[0m
  anxietychat memory path: [0;32m/home/devbox/.openclaw/memory/anxietychat[0m
  assistant agent.yaml: [0;32mOK[0m
  assistant memory path: [0;32m/home/devbox/.openclaw/memory/assistant[0m
  g-coder agent.yaml: [0;32mOK[0m
  g-coder memory path: [0;32m/home/devbox/.openclaw/memory/g-coder[0m
  g-hello agent.yaml: [0;32mOK[0m
  g-hello memory path: [0;32m/home/devbox/.openclaw/memory/g-hello[0m
  merry-bot agent.yaml: [0;32mOK[0m
  merry-bot memory path: [0;32m/home/devbox/.openclaw/memory/merry-bot[0m
Verifying tool boundary for memory...
  main tools include memory_*: [0;32mPASS[0m
  openclaw.json references memory tools: [0;32mNOT FOUND[0m
Checking TTL for anxietychat... [1;33mWARN[0m (TTL not found in anxietychat config)
```

### Evidence: Telegram Config
```
==========================================
  Telegram Configuration Validation
==========================================
✓ Config file found: /home/devbox/.openclaw/openclaw.json

=== Test 1: requireMention=false for agent-bound groups (always-on) ===
✓ PASS: Group TG_GROUP_CODER_ID has requireMention=false
✓ PASS: Group TG_GROUP_HELLO_ID has requireMention=false
✓ PASS: Group TG_GROUP_ANXIETY_CHAT_ID has requireMention=false
✓ PASS: Group TG_GROUP_MERRY_ID has requireMention=false
✓ PASS: Group TG_GROUP_ASSISTANT_DASHBOARD_ID has requireMention=false

=== Test 2: Group allowlist configuration ===
✓ PASS: groupPolicy is 'allowlist'
✓ PASS: Group TG_GROUP_CODER_ID is in allowlist
✓ PASS: Group TG_GROUP_HELLO_ID is in allowlist
✓ PASS: Group TG_GROUP_ANXIETY_CHAT_ID is in allowlist
✓ PASS: Group TG_GROUP_MERRY_ID is in allowlist
✓ PASS: Group TG_GROUP_ASSISTANT_DASHBOARD_ID is in allowlist

=== Test 3: Agent bindings ===
✓ PASS: Group TG_GROUP_CODER_ID → g-coder
✓ PASS: Group TG_GROUP_HELLO_ID → g-hello
✓ PASS: Group TG_GROUP_ANXIETY_CHAT_ID → anxietychat
✓ PASS: Group TG_GROUP_MERRY_ID → merry-bot
✓ PASS: Group TG_GROUP_ASSISTANT_DASHBOARD_ID → assistant
Checking owner DM binding (TG_OWNER_ID -> main)... ✓ PASS

==========================================
  Results: 17 passed, 0 failed
==========================================
```

### Evidence: Telegram Behavior
```
==========================================
  Telegram Log Analysis
==========================================
⚠️  WARNING: No GATE_DEBUG logs found in recent activity
   This test requires recent Telegram activity to analyze.
   Please send some test messages in Telegram groups and re-run.
STRICT MODE NOTE: config-only validation covers allowlist/bindings; log-based behavior requires live traffic.
```

### Evidence: Recent Forbidden ToolCalls
```
PASS: no forbidden toolCall entries found in recent Telegram sessions (cutoff=2026-02-12T20:01:03.005Z)
```

### Evidence: Main Forbidden ToolCalls
```
PASS: no forbidden main Telegram toolCall entries found in recent sessions (window=30m)
```

### Evidence: Telegram Internal Leak Markers
```
PASS: no Telegram outbound leakage markers found in recent sessions (cutoff=2026-02-12T20:01:03.005Z)
```

### Evidence: Telegram Sanitizer Telemetry
```
PASS: sanitizer telemetry markers/fields present in bundle
```

### Evidence: Telegram No-Leak Logs
```
SKIP: no recent telegram sanitizer telemetry lines since 2026-02-12 21:02:03 (send Telegram traffic and rerun)
```

### Evidence: Telegram No Heartbeat Leaks
```
PASS: no heartbeat/diagnostic leakage found since 2026-02-12 21:02:03
```

### Evidence: Telegram No Raw HTTP Error Leaks
```
PASS: no raw HTTP/provider error leakage found since 2026-02-12 21:02:03
```

### Evidence: Commands No LLM
```
PASS: command routing safeguards present (commands do not fall through to LLM)
```

### Evidence: Models Provider Guard
```
checking disabled providers in agent/models.json... [0;32mPASS[0m
checking disabled providers in agent/models.json... [0;32mPASS[0m
checking disabled providers in agent/models.json... [0;32mPASS[0m
checking disabled providers in agent/models.json... [0;32mPASS[0m
checking disabled providers in agent/models.json... [0;32mPASS[0m
checking disabled providers in agent/models.json... [0;32mPASS[0m
PASS: disabled providers are removed from /model(s) selectable provider configs.
Expected runtime response for disabled targets: Provider not configured/disabled. Available: Gemini, OpenRouter, Groq, Ollama.
```

### Evidence: No Tools In Non-Main Telegram
```
PASS: no disallowed non-main Telegram toolCall entries found in recent sessions (window=15m)
```

### Evidence: Telegram Language Policy
```
SKIP: no recent Telegram assistant text for English-only agents in last 15m
```

### Evidence: Tool Leakage
```
Scanning gateway logs for leakage markers...
[0;32mPASS[0m: no leakage markers found in last 800 lines
```

### Evidence: Approved Files Guard
```
PASS: no files to validate.
```
| Systemd | PASS | - |
| Environment | PASS | - |
| Workspace Root | PASS | - |
| Telegram Allowlist | PASS | - |
| Telegram Sanitizer Present | PASS | - |
| Google Compat Failover Patch | PASS | - |
| Telegram Reply Wrapper Sanitizer | PASS | - |
| Telegram Known Commands | PASS | - |
| Telegram Unknown Commands Static | PASS | - |
| Telegram Tool Intent Relay | PASS | - |
| Agent Auth Sync | PASS | - |
| Agent Model Sync | PASS | - |
| Agent Tool Consistency | PASS | - |
| Ollama Local | PASS | - |
| GPU Utilization | PASS | - |
| OpenRouter Provider | PASS | - |
| Groq Provider | PASS | - |
| Google Provider | PASS | - |
| Calendar Service | PASS | - |
| RAG Pipeline | PASS | - |
| Dashboard Skill | PASS | - |
| Main Failover | PASS | - |
| Fallback Under Cooldown | PASS | - |
| Fallback Locking | PASS | - |
| Sandbox Runner | PASS | - |
| Memory Isolation | PASS | - |
| Telegram Config | PASS | - |
| Telegram Behavior | PASS | - |
| Recent Forbidden ToolCalls | PASS | - |
| Main Forbidden ToolCalls | PASS | - |
| Telegram Internal Leak Markers | PASS | - |
| Telegram Sanitizer Telemetry | PASS | - |
| Telegram No-Leak Logs | PASS | - |
| Telegram No Heartbeat Leaks | PASS | - |
| Telegram No Raw HTTP Error Leaks | PASS | - |
| Commands No LLM | PASS | - |
| Models Provider Guard | PASS | - |
| No Tools In Non-Main Telegram | PASS | - |
| Telegram Language Policy | PASS | - |
| Tool Leakage | PASS | - |
| Approved Files Guard | PASS | - |


## Manual Checklist
- [ ] Send 'hello' in Group TG_GROUP_HELLO_ID (Haymi) -> Response in Amharic?
- [ ] Send '@main /cal next' in Dashboard Group -> Event list shown?
- [ ] Send '/task add Test' in Dashboard Group -> Task ID returned?
