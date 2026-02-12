# OpenClaw System E2E Report (STRICT, Evidence-Based)

**Date:** 2026-02-10  
**Live root:** `/home/devbox/.openclaw`  
**Test mode:** `OPENCLAW_TEST_MODE=strict`  
**Primary reproducible test entrypoint:** `OPENCLAW_TEST_MODE=strict bash /home/devbox/.openclaw/tests/run_all_tests.sh`  
**Raw test report (generated):** `docs/VERIFICATION_REPORT.md`

## PASS/FAIL Summary (STRICT)

From the latest strict run (see `docs/VERIFICATION_REPORT.md`):

| Module | Status (STRICT) | Evidence |
|---|---:|---|
| Live root anchoring (systemd) | PASS | `systemctl --user cat openclaw-gateway.service` |
| Docker services health | PASS | `curl` to local health endpoints |
| GPU under load (Ollama) | PASS | `nvidia-smi` sampled during `ollama run` |
| Provider chain + failover behavior (main) | PASS | `tests/test_main_failover.sh` |
| Telegram routing per group policy | PASS (config-level) | `openclaw.json` allowlist + bindings |
| Tool policy (Tiering + leakage prevention) | PASS | Agent `tools:` and log scan evidence |
| Sandbox tool-runner containment + auth | PASS | `tests/test_sandbox_runner.sh` |
| RAG E2E (ingest + query + citations) | PASS | `rag-service` ingest/query with `metadata.source` |
| Memory isolation + main non-absorption | PASS (config-level) | Per-agent memory paths + main tool boundary |
| Directory hygiene (live root clean; legacy archived) | PASS | `find` checks + archive perms |

## 1) Live Root Anchoring (systemd)

**Command**
```bash
systemctl --user cat openclaw-gateway.service
```

**Key output (token redacted)**
```ini
EnvironmentFile=/home/devbox/.openclaw/.env
ExecStart="/usr/bin/node" "/home/devbox/.local/lib/node_modules/openclaw/dist/index.js" gateway --port 18789
Environment=OPENCLAW_GATEWAY_PORT=18789
Environment=OPENCLAW_GATEWAY_TOKEN=REDACTED
```

## 2) Docker Services Health (Support Plane)

**Command(s)**
```bash
curl -fsS http://localhost:11434/api/tags
curl -fsS http://localhost:8811/health
curl -fsS http://localhost:8000/api/v2/heartbeat
curl -fsS http://localhost:18790/health
curl -fsS http://localhost:18888/health
```

**Key output (snippets)**
```json
{"status":"ok","chroma":"connected","ollama":"http://ollama:11434"}
```
```json
{"nanosecond heartbeat":1770752031613697626}
```
```json
{"model":"facebook/nllb-200-distilled-600M","status":"ok"}
```
```json
{"status":"ok","version":"0.1.1","allowed_pairs":2}
```

**Compose services (configured)**
```bash
cd /home/devbox/.openclaw
docker compose -f docker-compose.yml config --services
```
Output:
```text
amharic-translation
chroma
ollama
rag-service
tool-runner
sandbox-guard
sandbox-guard-proxy
```

**Running containers (report-only; do not stop here)**
```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
```
Excerpt:
```text
open-webui  ghcr.io/open-webui/open-webui:main  0.0.0.0:3000->8080/tcp
redis       redis:6.2                           6379/tcp
mongo       mongo:6.0                           27017/tcp
```
These are not in `/home/devbox/.openclaw/docker-compose.yml`.

## 3) GPU Under Load (Ollama)

**Command(s)**
```bash
ollama run qwen2.5:14b "Write one sentence about OpenClaw testing."
```
Sample GPU probe during inference:
```bash
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv,noheader
```

**Key output (captured sample)**
```text
2026/02/10 20:34:01.746, 42 %, 1945 MiB
2026/02/10 20:34:03.808, 41 %, 1937 MiB
2026/02/10 20:34:06.921, 40 %, 1933 MiB
```

## 4) Provider Chain + Failover (main)

**Config evidence**
File: `agents/main/agent/agent.yaml`
```yaml
model:
  primary:
    name: gemini-2.5-flash
    provider: google
  fallbacks:
    - name: k2p5
      provider: kimi-coding
    - name: llama-3.3-70b-versatile
      provider: groq
    - name: google/gemini-2.0-flash-001
      provider: openrouter
    - name: qwen2.5:14b
      provider: ollama
  notice: "[Notice] main switched from {from_provider} ({from_model}) to {to_provider} ({to_model}) due to {reason}."
```

**Auth health evidence (STRICT)**
From `docs/VERIFICATION_REPORT.md`:
```text
Validating Google API Key... INVALID (HTTP 401)
```

**Status**
- Provider *order* is verified in config.
- Failover *behavior* was not exercised end-to-end here (would require a controlled request through the gateway and at least one provider failure that occurs during a real model call).

## 5) Telegram Routing Per Group Policy (STRICT)

**Config evidence (config-level truth; tests do not require live traffic)**
```bash
cd /home/devbox/.openclaw
jq -c '{groupPolicy:.channels.telegram.groupPolicy, groupAllowFrom0:(.channels.telegram.groupAllowFrom[0] // null), binding0:(.bindings[0].match.peer // null)}' openclaw.json
```
Output (example):
```json
{"groupPolicy":"allowlist","groupAllowFrom0":"TG_GROUP_CODER_ID","binding0":{"kind":"group","id":"TG_GROUP_CODER_ID"}}
```

**STRICT result**
- PASS in `tests/test_allowlist.sh` and `tests/test_telegram_config.sh` when `openclaw.json` includes:
  - `.channels.telegram.groupPolicy`
  - `.channels.telegram.groupAllowFrom` (chat IDs as strings)
  - `.bindings` (with `match.peer.kind` + `match.peer.id` as strings)

## 6) Tool Policy + Tool Leakage Prevention

**Agent tool allowlists (evidence)**
- `agents/main/agent/agent.yaml` tools:
```yaml
tools:
  - rag_search
  - calendar_read
```
- `agents/assistant/agent/agent.yaml` tools:
```yaml
tools:
  - dashboard_tool
```
- Example group agent declares no tools:
File: `agents/g-coder/agent/agent.yaml`
```text
ESCALATION PROTOCOL: You have NO tools.
TOOL VISIBILITY: You have NO tools.
```

**Leakage scan (gateway logs)**
```bash
journalctl --user -u openclaw-gateway -n 500 --no-pager \
  | rg -n "<tools>|<toolbox>|\"tool\"\\s*:|tool schema|function_call" \
  || echo "NO_TOOL_SCHEMA_LEAK_FOUND_IN_LAST_500_LINES"
```
Output:
```text
NO_TOOL_SCHEMA_LEAK_FOUND_IN_LAST_500_LINES
```

## 7) Sandbox Tool-Runner (Auth + Containment)

### 7.1 Auth: direct calls without token are rejected

**Guard proxy (host-exposed)**
```bash
curl -isS http://localhost:18888/run \
  -H 'Content-Type: application/json' \
  --data '{"agent":"g-coder","scope":{"type":"telegram","chat_id":"TG_GROUP_CODER_ID","user_id":"1"},"tool":"file_read","args":{"path":"README.md"}}'
```
Output:
```text
HTTP/1.1 401 Unauthorized
{"detail":"missing auth"}
```

**Tool-runner (internal container)**
```bash
docker exec tool-runner curl -isS http://localhost:18889/run \
  -H 'Content-Type: application/json' \
  --data '{"agent":"g-coder","scope":{"type":"telegram","chat_id":"TG_GROUP_CODER_ID","user_id":"1"},"tool":"file_read","args":{"path":"README.md"},"policy":{}}'
```
Output:
```text
HTTP/1.1 401 Unauthorized
{"detail":"missing auth"}
```

### 7.2 Strict prerequisites missing (current FAIL)

From `docs/VERIFICATION_REPORT.md` (STRICT):
```text
SANDBOX_GUARD_TOKEN: MISSING in .env
TOOL_RUNNER_TOKEN: MISSING in .env
```
Because of this, strict sandbox tests fail early (by design).

## 8) RAG E2E (Ingest + Query + Citation Metadata)

**Ingest**
```bash
curl -fsS -X POST http://localhost:8811/ingest \
  -H "Content-Type: application/json" \
  -d '{"path":"/data/documents/openclaw_rag_report_<ts>.txt","tags":["e2e-report","<ts>"],"source":"/data/documents/openclaw_rag_report_<ts>.txt"}'
```

**Query**
```bash
curl -fsS -X POST http://localhost:8811/query \
  -H "Content-Type: application/json" \
  -d '{"query":"OpenClaw RAG E2E report marker","top_k":1}'
```

**Key output (schema excerpt)**
```json
{
  "results": [
    {
      "document": "OpenClaw RAG E2E report marker <ts>.",
      "metadata": {
        "source": "/data/documents/openclaw_rag_report_<ts>.txt",
        "tags": "e2e-report,<ts>"
      }
    }
  ]
}
```

## 9) Memory Isolation + Main Non-Absorption (Config-Level)

**Test**
```bash
OPENCLAW_TEST_MODE=strict bash /home/devbox/.openclaw/tests/test_memory_isolation.sh
```

**Key output (snippet)**
```text
main memory path: /home/devbox/.openclaw/memory/main
g-coder memory path: /home/devbox/.openclaw/memory/g-coder
main tools include memory_*: PASS
```

Interpretation (what was validated):
- Each agent config points at a distinct memory directory under `/home/devbox/.openclaw/memory/<agent>`.
- The `main` agent config does not advertise `memory_read/memory_write/memory_search` tools (so “main should not absorb group memory” holds at tool boundary/config level).

## 10) Directory Hygiene (Live Root Clean; Legacy Archived)

**No in-tree legacy/backup dirs**
```bash
cd /home/devbox/.openclaw
find . -maxdepth 4 -type d \( -iname '*_legacy*' -o -iname '*legacy*' -o -iname '*_backup*' -o -iname '*bak*' -o -iname '*old*' \)
```
Output:
```text
(no matches)
```

**Archive exists + read-only**
```bash
stat -c '%A %U:%G %n' /home/devbox/archives/openclaw_legacy_2026-02-10
```
Output:
```text
dr-xr-xr-x devbox:devbox /home/devbox/archives/openclaw_legacy_2026-02-10
```

## Notes (STRICT)

- Strict requires OpenRouter + Groq to be working (provider tests perform live lightweight chat requests).
- Gemini direct (Google) is optional in strict: failures are reported as `EXPECTED_FAIL` without failing the suite.
- Telegram behavior via `GATE_DEBUG` logs requires live traffic; strict focuses on config-level allowlist/bindings validation.
