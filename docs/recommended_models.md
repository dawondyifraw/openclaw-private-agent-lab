# Recommended Models

## Required Local Ollama Models
These models must be present locally:
- `qwen2.5:14b`
- `mistral-nemo:12b`
- `wngtcalex/mythomax-13b`
- `glm-4.7`

## Pull + Verify
Run:

```bash
bash /home/devbox/.openclaw/scripts/pull_ollama_models.sh
```

## Confirm Inventory
Run:

```bash
ollama list
```

All agents are configured to access the shared local Ollama inventory, with `qwen2.5:14b` locked as the last fallback.

## Cloud Note (Mistral)
Assistant uses `mistral-large-2411` as primary via the configured Mistral provider.
`MISTRAL_API_KEY` must be set in `.env` (do not print or log key values).
