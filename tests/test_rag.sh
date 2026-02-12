#!/bin/bash
# tests/test_rag.sh
# Verifies RAG-service health and ingestion/query flow using Ollama embeddings.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -n "Checking RAG-service health... "
if curl -fsS http://localhost:8811/health > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    exit 1
fi

echo "Verifying RAG ingestion and retrieval..."
# Use a directory mounted in docker-compose.yml: ./data/documents -> /data/documents
HOST_DOCS_DIR="/home/devbox/.openclaw/data/documents"
mkdir -p "$HOST_DOCS_DIR"
TEST_FILE_NAME="openclaw_rag_test.txt"
TEST_FILE_HOST="$HOST_DOCS_DIR/$TEST_FILE_NAME"
TEST_FILE_CONTAINER="/data/documents/$TEST_FILE_NAME"

echo "OpenClaw is a modular AI agent framework." > "$TEST_FILE_HOST"

# Ingest (pass the container path to the API)
INGEST_R=$(curl -s -X POST http://localhost:8811/ingest \
    -H "Content-Type: application/json" \
    -d "{\"path\": \"$TEST_FILE_CONTAINER\", \"tags\": [\"e2e-test\"]}")

if echo "$INGEST_R" | jq -e '.status == "success"' > /dev/null 2>&1; then
    echo -e "  Ingestion: ${GREEN}OK${NC}"
else
    echo -e "  Ingestion: ${RED}FAIL${NC}"
    echo "  Response: $INGEST_R"
    exit 1
fi

# Query
QUERY_R=$(curl -s -X POST http://localhost:8811/query \
    -H "Content-Type: application/json" \
    -d '{"query": "What is OpenClaw?", "top_k": 1}')

if echo "$QUERY_R" | grep -qE "modular AI agent framework|powerful multi-agent system" && echo "$QUERY_R" | grep -q "source"; then
    echo -e "  Retrieval: ${GREEN}OK${NC}"
else
    echo -e "  Retrieval: ${RED}FAIL${NC}"
    echo "  Response: $QUERY_R"
    exit 1
fi

rm "$TEST_FILE_HOST"
