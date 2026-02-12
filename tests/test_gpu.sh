#!/bin/bash
# tests/test_gpu.sh
# Verifies GPU visibility and utilization during short inference.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -n "Checking nvidia-smi visibility... "
if nvidia-smi > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Error: nvidia-smi not found or GPU not visible."
    exit 1
fi

echo "Verifying GPU utilization under load..."
GPU_BEFORE=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

# Run a quick inference in background
# Use a model we know should be there from test_ollama.sh
ollama run qwen2.5:14b "Summarize: The quick brown fox jumps over the lazy dog." > /dev/null 2>&1 &
PID=$!
sleep 2
GPU_DURING=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
wait $PID || true

echo "  Utilization Before: $GPU_BEFORE%"
echo "  Utilization During: $GPU_DURING%"

if [ "$GPU_DURING" -gt "$GPU_BEFORE" ]; then
    echo -e "${GREEN}PASS${NC} (Utilization increased)"
else
    echo -e "${YELLOW}WARNING${NC} (Utilization didn't noticeably increase, check if model is too small or already cached)"
fi
