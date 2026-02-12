#!/usr/bin/env bash
set -euo pipefail

RAG_URL="http://localhost:8811"
OLLAMA_URL="http://localhost:11434"

echo "== RAG Smoke Test =="

# 1. Embeddings Health
echo "-- 1. Embeddings Health --"
curl -fsS -X POST "${OLLAMA_URL}/api/embeddings" -d '{"model":"nomic-embed-text","prompt":"test"}' > /dev/null \
  && echo "PASS: Ollama embeddings (nomic-embed-text) active" \
  || (echo "FAIL: nomic-embed-text not responding" && exit 1)

# 2. RAG Service Health
echo "-- 2. RAG Service Health --"
HEALTH=$(curl -fsS "${RAG_URL}/health")
echo "${HEALTH}" | grep -q "ok" \
  && echo "PASS: rag-service health ok" \
  || (echo "FAIL: rag-service unhealthy or unreachable" && exit 1)

# 3. Ingestion Test
echo "-- 3. Ingestion Test --"
echo "Creating dummy document..."
# Ensure the directory exists in the mapped host path
mkdir -p /home/devbox/.openclaw/data/documents
echo "OpenClaw is a powerful multi-agent system." > /home/devbox/.openclaw/data/documents/test_info.txt

# Triggering ingestion (using container path mapping)
curl -fsS -X POST "${RAG_URL}/ingest" -H "Content-Type: application/json" -d '{"path":"/data/documents/test_info.txt","tags":["test"]}' > /dev/null \
  && echo "PASS: Ingestion successful" \
  || (echo "FAIL: Ingestion failed" && exit 1)

# 4. Query Test
echo "-- 4. Query Test --"
QUERY_RESULT=$(curl -fsS -X POST "${RAG_URL}/query" -H "Content-Type: application/json" -d '{"query":"What is OpenClaw?", "top_k": 1}')
echo "${QUERY_RESULT}" | grep -q "OpenClaw" \
  && echo "PASS: Query returned relevant text" \
  || (echo "FAIL: Query did not return expected document content" && exit 1)

echo "-- 5. Metadata Check --"
echo "${QUERY_RESULT}" | grep -q "source" \
  && echo "PASS: Metadata present in results" \
  || (echo "FAIL: Metadata missing from query results" && exit 1)

echo "== ALL RAG TESTS PASSED =="
