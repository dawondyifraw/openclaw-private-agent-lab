# OpenClaw Multi-Agent System - Memory Policy

## Memory Classes

### 1. FACTS (Operational Memory)
- Stable, security-relevant, operational data
- Always scoped and testable
- Examples:
  - User timezone preferences
  - Telegram group language settings
  - Agent routing rules
  - System configuration state

### 2. FLAVOR (Continuity Memory)
- Fun, non-critical interaction history
- Must NEVER affect routing, security, or credentials
- Examples:
  - User's preferred greeting style
  - Conversation tone preferences
  - Casual interaction patterns

## Memory Scopes

1. **Per-Agent Memory**
   - `/home/devbox/.openclaw/memory/{agent-name}/`
   - Isolated per agent
   - No cross-agent reads

2. **Per-Group Memory (Telegram)**
   - Scoped to specific Telegram group ID
   - Language routing metadata
   - Group-specific preferences

3. **Minimal Global Memory**
   - System-wide operational state only
   - No user-specific data

## Storage Rules

- Memory is **opt-in only**
- Requires explicit user command to write
- Emotional state is **never stored**
- Only user-stated interaction preferences may be stored if explicitly requested

## Enforcement

- Router mounts correct memory directory per agent
- Filesystem access restricted to agent's own memory scope
- Cross-agent memory reads are blocked
- Memory write events logged (metadata only, no content)
