#!/usr/bin/env bash
set -euo pipefail

URL="${OLLAMA_BENCH_URL:-http://localhost:11434/api/generate}"
MODEL="${OLLAMA_BENCH_MODEL:-qwen2.5:14b}"
RUNS="${OLLAMA_BENCH_RUNS:-5}"
PROMPT="${OLLAMA_BENCH_PROMPT:-Reply with exactly: OK}"

if ! command -v curl >/dev/null 2>&1; then
  echo "FAIL: curl is required"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required"
  exit 1
fi

echo "Ollama benchmark"
echo "  url=$URL"
echo "  model=$MODEL"
echo "  runs=$RUNS"

total_ms=0
ok=0

for i in $(seq 1 "$RUNS"); do
  start_ms=$(date +%s%3N)
  http_code=$(curl -sS -o /tmp/ollama_bench_run.json -w "%{http_code}" \
    -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${MODEL}\",\"prompt\":\"${PROMPT}\",\"stream\":false}")
  end_ms=$(date +%s%3N)
  dur_ms=$((end_ms - start_ms))

  if [ "$http_code" = "200" ] && jq -e '.response | type=="string"' /tmp/ollama_bench_run.json >/dev/null 2>&1; then
    ok=$((ok + 1))
    total_ms=$((total_ms + dur_ms))
    echo "run $i: ${dur_ms}ms OK"
  else
    echo "run $i: ${dur_ms}ms FAIL (http=${http_code})"
  fi
done

if [ "$ok" -eq 0 ]; then
  echo "FAIL: all runs failed"
  exit 1
fi

avg_ms=$((total_ms / ok))
echo "summary: success=${ok}/${RUNS} avg_ms=${avg_ms}"

