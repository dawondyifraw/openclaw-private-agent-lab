# Persona Status (Runtime Verification)

Date: 2026-02-11

Verified runtime persona files:
- `agents/main/agent/agent.yaml`
- `agents/assistant/agent/agent.yaml`
- `agents/g-coder/agent/agent.yaml`
- `agents/g-hello/agent/agent.yaml`
- `agents/anxietychat/agent/agent.yaml`
- `agents/merry-bot/agent/agent.yaml`

Findings:
- All six runtime persona files exist on host runtime.
- Assistant persona file is runtime-only in this repo model (not tracked as `agent.yaml`), now covered by tracked template `agents/assistant/agent/agent.yaml.example`.
- Current runtime prompts are plain-text oriented and explicitly ban tool narration.
- No `JSON-ONLY AGENT` directives were found in current runtime versions for the six agents.

Tracked template coverage:
- `agents/main/agent/agent.yaml.example`
- `agents/assistant/agent/agent.yaml.example`
- `agents/g-coder/agent/agent.yaml.example`
- `agents/g-hello/agent/agent.yaml.example`
- `agents/anxietychat/agent/agent.yaml.example`
- `agents/merry-bot/agent/agent.yaml.example`
- `agents/g-moltd/agent/agent.yaml.example`

Rehydrate command:
```bash
for a in main assistant g-coder g-hello anxietychat merry-bot g-moltd; do
  cp -n "agents/$a/agent/agent.yaml.example" "agents/$a/agent/agent.yaml"
done
```
