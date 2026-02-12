#!/usr/bin/env bash
set -euo pipefail

echo "== 1) systemd service =="
systemctl --user is-active --quiet openclaw-gateway.service && echo "PASS: systemd active" || (echo "FAIL: systemd inactive" && exit 1)

echo "== 2) docker support services =="
docker ps --format '{{.Names}}' | grep -q '^ollama$' && echo "PASS: ollama running" || (echo "FAIL: ollama missing" && exit 1)
docker ps --format '{{.Names}}' | grep -q 'amharic' && echo "PASS: amharic service running" || echo "WARN: amharic container name not matched"

echo "== 3) host -> docker connectivity =="
curl -fsS http://localhost:11434/api/tags >/dev/null && echo "PASS: ollama reachable" || (echo "FAIL: ollama unreachable" && exit 1)
curl -fsS http://localhost:18790/health >/dev/null && echo "PASS: amharic reachable" || echo "WARN: amharic health endpoint not found"

echo "== 4) GPU visibility (container) =="
docker exec -i ollama nvidia-smi >/dev/null && echo "PASS: GPU visible in ollama container" || echo "WARN: nvidia-smi failed in container"

echo "== DONE =="
