# Performance & Stability Guide

This document covers low-risk tuning only. It does not change routing, tool policy, or provider architecture.

## 1) Ollama GPU Checklist

1. Confirm GPU is visible on host:
   - `nvidia-smi`
2. Confirm Ollama container is healthy:
   - `curl -fsS http://localhost:11434/api/tags`
3. Confirm Docker compose service is running from live root:
   - `docker compose -f /home/devbox/.openclaw/docker-compose.yml ps ollama`

## 2) Recommended Ollama Knobs (Conservative Defaults)

Set in runtime `.env` (values shown are starting points):

- `OLLAMA_NUM_PARALLEL=1`
- `OLLAMA_MAX_LOADED_MODELS=1`
- `OLLAMA_KEEP_ALIVE=15m`

Why:
- Lower parallelism reduces timeout spikes under mixed cloud/local fallback.
- Limiting loaded models reduces VRAM thrash/swapping.
- Keep-alive avoids repeated cold starts.

## 3) Benchmark Before/After

Run:

- `bash /home/devbox/.openclaw/scripts/bench_ollama.sh`

Optional overrides:

- `OLLAMA_BENCH_MODEL=qwen2.5:14b OLLAMA_BENCH_RUNS=5 bash scripts/bench_ollama.sh`

Compare `avg_ms` before and after changing knobs.

## 4) Flash Attention Status (Evidence Required)

Do not assume flash attention is enabled.

Check:

- `docker logs ollama --tail 200`

If your build does not explicitly expose/document a flash-attention flag, treat status as **UNKNOWN/NOT SUPPORTED** and do not claim it is active.

## 5) Avoid Cooldown Storms

Use config examples (not runtime overwrites) to keep prompts compact and avoid repeated overflow retries:

- `agents.defaults.compaction.mode: "safeguard"`
- `agents.defaults.compaction.reserveTokensFloor: 1500`

Apply in runtime `openclaw.json` only after validation in your environment.

## 6) Common Symptoms and Safe Actions

- `Gateway timeout after 10 seconds`
  - Reduce local concurrency (`OLLAMA_NUM_PARALLEL=1`)
  - Verify provider keys for cloud fallbacks
- `Context limit exceeded`
  - Raise compaction reserve floor and keep history compact
- Provider cooldown storms
  - Keep Gemini/OpenRouter ahead of Groq for always-on groups
- Wrong-language output in English-only scopes
  - Enforce prompt language constraints and verify strict language-policy tests

