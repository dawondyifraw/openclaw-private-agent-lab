#!/bin/bash
# tests/test_ollama.sh
# Verifies Ollama connectivity and local model availability.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -n "Checking Ollama connectivity... "
if curl -fsS http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Error: Ollama service is unreachable on http://localhost:11434"
    exit 1
fi

REQUIRED_MODELS=(
  "qwen2.5:14b"
  "qwen2.5-coder:14b"
  "mistral-nemo:12b"
  "dolphin3:8b"
  "wngtcalex/mythomax-13b"
  "glm-4.7"
)
EXISTING_MODELS=$(curl -s http://localhost:11434/api/tags | jq -r '.models[].name')

echo "Checking required models..."
for model in "${REQUIRED_MODELS[@]}"; do
    echo -n "  $model: "
    if echo "$EXISTING_MODELS" | grep -q "^$model"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}MISSING${NC}"
        MISSING=true
    fi
done

if [ "$MISSING" == "true" ]; then
    echo "Action: Run 'ollama pull <model-name>' for missing models."
    exit 1
fi
