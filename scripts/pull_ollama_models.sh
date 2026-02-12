#!/usr/bin/env bash
set -euo pipefail

# Pull and verify required local Ollama models for OpenClaw.

MODELS=(
  "wngtcalex/mythomax-13b"
  "glm-4.7"
  "mistral-nemo:12b"
  "qwen2.5:14b"
)

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FAIL: missing command: $1" >&2
    exit 1
  }
}

ollama_cmd() {
  if command -v ollama >/dev/null 2>&1; then
    ollama "$@"
    return
  fi
  docker exec ollama ollama "$@"
}

has_model() {
  local model="$1"
  ollama_cmd list | rg -q "^${model}([[:space:]]|:)"
}

need_cmd rg
need_cmd docker

MISSING_MODELS=()
PULL_ERRORS=()

echo "Pulling required Ollama models..."
for model in "${MODELS[@]}"; do
  if has_model "$model"; then
    echo "  OK (present): $model"
    continue
  fi
  echo "  Pulling: $model"
  if ! ollama_cmd pull "$model"; then
    echo "  WARN: pull failed for $model (continuing best-effort)"
    PULL_ERRORS+=("$model")
  fi
done

echo "Verifying required Ollama models..."
for model in "${MODELS[@]}"; do
  if has_model "$model"; then
    echo "  OK: $model"
  else
    echo "  MISSING: $model"
    MISSING_MODELS+=("$model")
  fi
done

if ((${#PULL_ERRORS[@]} > 0)); then
  echo "WARN: pull errors for: ${PULL_ERRORS[*]}"
fi

if ((${#MISSING_MODELS[@]} > 0)); then
  echo "WARN: missing models after best-effort pull: ${MISSING_MODELS[*]}"
  echo "Strict suite enforces required models for active profile via tests/test_ollama.sh."
else
  echo "PASS: required Ollama models are present."
fi
