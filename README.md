# OpenClaw Home Lab Architecture

## 1. Overview
This system is a multi-agent orchestration environment built on OpenClaw. It serves as a personal home lab for agentic experimentation, automated translation routing, and mixed cloud/local model execution.

It is **NOT** a production-grade secured sandbox. It is an operational environment where security and isolation are managed through logical policy and configuration rather than physical or process-level boundaries.

## 2. Starting Point
The canonical working directory for this system is `/home/devbox/.openclaw`. This is where the core configuration lives. OpenClaw operates in a **host-native mode** for orchestrating agents, while **Docker** handles support services only.

## 3. Repository Layout & Rule of Thumb
### Explicit Rule:
- **Always maintain project-specific files** (configs, tools, agents) within the `/home/devbox/.openclaw` directory structure.
- **Always execute scripts and CLI commands from the `/home/devbox/.openclaw` directory** to avoid path resolution errors for logs and relative configuration paths.

| Component | Files / Location | Recommended Execution Root |
|-----------|------------------|---------------------------|
| **Global Config** | `openclaw.json`, `.env` | `/home/devbox/.openclaw` |
| **Agent Logic** | `agents/` | `/home/devbox/.openclaw` |
| **Custom Tools** | `tools/` | `/home/devbox/.openclaw` |
| **Infrastructure** | `docker-compose.yml` | `/home/devbox/.openclaw` |
| **Tests** | `tests/` | `/home/devbox/.openclaw` |
| **Ops Scripts** | `scripts/` | `/home/devbox/.openclaw` |

## 4. Bootstrap Order (Clean Start)
Follow this precise sequence to start the system:

1.  **Preparation**: `cd /home/devbox/.openclaw`
2.  **Infrastructure**: `docker compose up -d`
3.  **Pre-flight Check**: `bash scripts/bootstrap_check.sh`
4.  **Verification**: `bash tests/run_all_tests.sh` (Runs tests *before* the main gateway is active to ensure support plane health).
5.  **Activation**: `systemctl --user start openclaw-gateway.service`
6.  **Smoke Test**: `openclaw agents list`

## 5. Safe Test-First Mode
Our verification suite (`tests/run_all_tests.sh`) is designed to be **non-invasive**:
- **Isolated Memory**: Tests use `/tmp/openclaw-test-memory` and temporary nonces. This ensures that running a verification check **does not pollute** or modify your active user sessions or agent memory in `~/.openclaw/memory/`.
- **Read-Only Ingestion**: RAG ingestion tests use synthetic test documents to verify the pipeline without affecting production indexes.
- **Workflow**: You can safely run tests at any time—even while the system is under development—to validate service availability without changing the state of the system for actual users.

## 6. Architecture Summary
Isolation in this system is logical and policy-based, aligned with OpenClaw documentation.

- **Workspace Isolation**: Each agent is assigned a dedicated directory for its memory and workspace. Cross-agent file access is denied by the orchestrator.
- **Tool Isolation**: Agents operate with explicit tool allowlists.
- **Session Isolation**: Interaction context is scoped to the current active session.

Isolation does **NOT** mean separate processes, separate Docker containers per agent, or network-level sandboxing. All agents share the host-native OpenClaw runtime.

## 4. Model Strategy
The system follows an explicit model locality policy. Every model binding must declare its provider (cloud or local), runtime (e.g., kimi or ollama), and endpoint.

- **Main Agent**: Uses Kimi cloud (`kimi-coding/k2p5`) as the primary provider. It is configured for automatic fallback to local Ollama (`qwen2.5:14b`) upon verified cloud failure.
- **Local Agents**: All other agents default to local-first execution via Ollama.
- **Fallback Behavior**: Fallbacks are triggered by timeouts, connection errors, or provider failures. The system notifies the user once upon a provider switch.

## 6. GPU Usage
GPU acceleration is utilized exclusively by the Ollama container for local model inference.
- **Where Used**: Within the Ollama Docker container for all local-runtime requests.
- **Verification**: Confirmed by monitoring VRAM allocation and utilization via `nvidia-smi` during active inference loops.
- **Non-Isolated**: There is no GPU-level isolation between agents; all agents requesting local inference share the same hardware resources.

## 7. RAG Knowledge Base
The system includes a dedicated Retrieval-Augmented Generation (RAG) capability for querying static document collections.

- **Separation from Memory**: RAG is distinct from operational agent memory. Agent memory stores conversation state and facts, while RAG stores indexed external knowledge (PDFs, MDs, TXTs).

### How to Use
#### Ingestion
Place documents in `data/documents/` and run the ingestion script:
```bash
# Ingest a specific folder or file
./services/rag-service/ingest.py /data/documents/my_folder tag1,tag2
```
*Note: The path must be relative to the container mount or the mapped host path.*

### Service Port Mapping
| Service | Host Port | Internal Port | Description |
|---------|-----------|---------------|-------------|
| Ollama | 11434 | 11434 | LLM Runtime |
| Chroma | 8000 | 8000 | Vector Database |
| RAG | 8811 | 18791 | RAG API Service |
| Dashboard | 18820 | 18820 | Dashboard Service |
| Calendar | 18821 | 18821 | Calendar Service |
| Amharic | 18790 | 18790 | Translation Middleware |

## 8. Memory Management
Memory is persistent, auditable, and strictly scoped per agent.
- **Memory Scope**: Scoped to individual agents and specific Telegram groups.
- **Write Rules**: Memory writes occur only upon explicit instruction or defined policy. Auto-learning and implicit state storage are disabled.
- **Persistence Guarantees**: State is stored in host-resident JSON/JSONL files and verified across service restarts.

## 9. Dashboard Skill
The Dashboard Skill provides task and reminder management scoped to specific groups (e.g., the Assistant group).

### Commands
- `/task add <text>`: Add a new task to the group list.
- `/task list`: List all active (undone) tasks.
- `/task done <id>`: Mark a specific task as completed.
- `/remind at <YYYY-MM-DD HH:MM> <text>`: Schedule a reminder.
- `/remind list`: List all pending reminders.
- `/remind cancel <id>`: Cancel a pending reminder.
- `/dash`: Show a summary of active tasks and reminders.

### Storage
- **Location**: `~/.openclaw/data/dashboard/<group_id>.json`
- **Reset**: Delete the specific JSON file in the dashboard data directory to reset a group's state.

## 10. Calendar Integration
Google Calendar read-only integration owned by the `@main` agent.

### Commands
- `/cal today`: Events for today.
- `/cal next`: Next 10 upcoming events.
- `/cal week`: Events for the next 7 days.
- `/cal search <keyword>`: Search for specific events.

### Security & Privacy
- **Read-Only**: Scope limited to `calendar.readonly`.
- **Minimization**: Descriptions and attendees are hidden by default unless explicitly asked.
- **Local Time**: Results use host local timezone (e.g., CET).
- **Storage**: `~/.openclaw/secrets/google_calendar_token.json` (chmod 600).

## 11. Telegram Routing
The Telegram gateway serves five authorized groups using an `allowlist` policy.
- **Allowlist Behavior**: Messages from non-authorized groups or DMs are ignored unless explicitly paired.
- **Language Middleware**: Two specific groups are routed through the Amharic translation service. Responses are intercepted and translated before delivery.

## 12. Persistence & Protection
Support services in this system are designed for data persistence across restarts, upgrades, and reboots.

### Persistent Volumes
| Service | Volume Name | Data Stored | Safe to Delete? |
|---------|-------------|-------------|-----------------|
| Ollama | `ollama_models` | Local LLM weights | **NO** |
| Chroma | `chroma_data` | RAG Vector Index | **NO** |
| Redis | Managed by Docker | Metadata cache | Yes |
| MongoDB | Managed by Docker | Session State | Yes |

### ⚠️ Critical Protection Rules
- **DO NOT** run `docker system prune` or `docker volume prune` unless you explicitly intend to wipe local LLMs and RAG data.
- **Model Persistence**: Once a model is pulled via `ollama pull`, it is resident in the `ollama_models` volume and protected from standard container lifecycle restarts.
- **Vector Persistence**: RAG indexes inhabit the `chroma_data` volume. Only a manual volume removal or the `ALLOW_RESET=TRUE` environment trigger (if invoked) will clear this data.

## 13. Testing & Verification
The system state is verified via the master E2E test runner.

**Run All Tests:**
```bash
bash tests/run_all_tests.sh
```

**Test Coverage:**
- **System Health**: Checks systemd service and container status.
- **Hardware**: Validates GPU visibility and utilization during inference.
- **RAG Pipeline**: E2E ingestion and query verification with metadata checks.
- **Security**: Verifies operational memory isolation and persistence.
- **Model Check**: Confirms explicit locality and fallback policies.

## 11. Repository Layout
```text
.openclaw/
├── .agent/prompts/       # Deterministic builder and tester prompts
├── agents/               # Agent definitions and YAML configs
├── data/                 # Static documents for RAG ingestion
├── services/             # Dockerfiles and source for support services (rag-service, amharic)
├── telegram/             # Routing and translation middleware configs
├── tests/                # Automated verification scripts
├── docker-compose.yml    # Support services definition (Ollama, Chroma, RAG)
├── openclaw.json         # Global system configuration
└── README.md             # This document
```

## 12. Planned / Future Additions (Optional)
- **Monitoring Dashboard**: Potential integration of metrics for agent response times and token usage.
- **Extended Local Models**: Evaluation of larger local weights as primary local handlers.

## 13. Design Principles
- **Explicit over Implicit**: No assumed defaults for model locality or provider types.
- **Atomic Operations**: Configuration changes must be validated before service restart.
- **Fail-Safe**: Local models serve as the ultimate fallback for system availability.

## 14. Rebuild Philosophy
This lab is designed for rehydration. By maintaining deterministic prompts and explicit configuration snapshots, the environment can be torn down and rebuilt to a known-good state with minimal manual intervention.
