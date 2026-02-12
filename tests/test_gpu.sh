#!/bin/bash
# tests/test_gpu.sh
# Verifies GPU visibility and utilization during short inference.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="${OPENCLAW_TEST_MODE:-default}"

echo -n "Checking nvidia-smi visibility... "
if nvidia-smi > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Error: nvidia-smi not found or GPU not visible."
    exit 1
fi

echo "Verifying GPU utilization under load..."
GPU_BEFORE=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1 | tr -d ' ')

# Run a quick inference in background
# Use a model we know should be there from test_ollama.sh
ollama run qwen2.5:14b "Summarize: The quick brown fox jumps over the lazy dog." > /dev/null 2>&1 &
PID=$!
GPU_MAX="$GPU_BEFORE"
for _ in 1 2 3 4 5; do
    sleep 1
    GPU_S=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1 | tr -d ' ')
    if [ "$GPU_S" -gt "$GPU_MAX" ]; then
        GPU_MAX="$GPU_S"
    fi
done
wait $PID || true

echo "  Utilization Before: $GPU_BEFORE%"
echo "  Utilization Max During: $GPU_MAX%"

if [ "$MODE" = "strict" ]; then
    # Strict: require evidence of non-zero GPU activity at least once during inference.
    if [ "$GPU_MAX" -gt 0 ]; then
        echo -e "${GREEN}PASS${NC} (GPU utilization observed during inference)"
    else
        echo -e "${RED}FAIL${NC} (No GPU utilization observed during inference)"
        exit 1
    fi
else
    if [ "$GPU_MAX" -gt "$GPU_BEFORE" ]; then
        echo -e "${GREEN}PASS${NC} (Utilization increased)"
    else
        echo -e "${YELLOW}WARNING${NC} (Utilization didn't noticeably increase, check if model is too small or already cached)"
    fi
fi
