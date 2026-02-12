#!/bin/bash
# tests/run_all_tests.sh
# Main entrypoint for the OpenClaw E2E Verification Suite.

set -e

BASE_DIR="/home/devbox/.openclaw"
DOCS_DIR="${BASE_DIR}/docs"
REPORT_FILE="${DOCS_DIR}/VERIFICATION_REPORT.md"
mkdir -p "${DOCS_DIR}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================================="
echo "      OPENCLAW E2E SYSTEM VERIFICATION                    "
echo "=========================================================="

# Header for Report
cat <<EOF > "${REPORT_FILE}"
# OpenClaw System Verification Report
**Date:** $(date)
**System Version:** $(openclaw --version 2>/dev/null || echo "2026.2.6-3")

## Summary Results
| Module | Status | Details |
|--------|--------|---------|
EOF

RESULTS_TABLE=""

run_test() {
    local name=$1
    local script=$2
    echo -n "Running $name... "
    set +e
    OUTPUT=$(bash "$script" 2>&1)
    EXIT_CODE=$?
    set -e
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
        RESULTS_TABLE+="| $name | PASS | - |"$'\n'
    else
        echo -e "${RED}FAIL${NC}"
        RESULTS_TABLE+="| $name | FAIL | See Evidence Section |"$'\n'
    fi
    
    echo -e "\n### Evidence: $name" >> "${REPORT_FILE}"
    echo '```' >> "${REPORT_FILE}"
    echo "$OUTPUT" >> "${REPORT_FILE}"
    echo '```' >> "${REPORT_FILE}"
}

# 1. Systemd
run_test "Systemd" "${BASE_DIR}/tests/test_systemd.sh"

# 2. Environment
run_test "Environment" "${BASE_DIR}/tests/test_env.sh"

# 3. Allowlist
run_test "Telegram Allowlist" "${BASE_DIR}/tests/test_allowlist.sh"

# 4. Agent Auth Sync
run_test "Agent Auth Sync" "${BASE_DIR}/tests/test_agent_auth_sync.sh"

# 5. Ollama
run_test "Ollama Local" "${BASE_DIR}/tests/test_ollama.sh"

# 6. GPU Usage
run_test "GPU Utilization" "${BASE_DIR}/tests/test_gpu.sh"

# 7. OpenRouter
run_test "OpenRouter Provider" "${BASE_DIR}/tests/test_openrouter.sh"

# 8. Google Provider
run_test "Google Provider" "${BASE_DIR}/tests/test_google_provider.sh"

# 9. Calendar
run_test "Calendar Service" "${BASE_DIR}/tests/test_calendar.sh"

# 10. RAG
run_test "RAG Pipeline" "${BASE_DIR}/tests/test_rag.sh"

# 11. Dashboard
run_test "Dashboard Skill" "${BASE_DIR}/tests/test_dashboard.sh"

# 12. Memory Isolation
if [ -f "${BASE_DIR}/tests/test_memory_isolation.sh" ]; then
    run_test "Memory Isolation" "${BASE_DIR}/tests/test_memory_isolation.sh"

    # 13. Telegram Configuration
    run_test "Telegram Config" "${BASE_DIR}/tests/test_telegram_config.sh"

    # 14. Telegram Logs
    run_test "Telegram Behavior" "${BASE_DIR}/tests/test_telegram_logs.sh"
fi

echo -e "$RESULTS_TABLE" >> "${REPORT_FILE}"

echo -e "\n## Manual Checklist" >> "${REPORT_FILE}"
cat <<EOF >> "${REPORT_FILE}"
- [ ] Send 'hello' in Group TG_GROUP_HELLO_ID (Haymi) -> Response in Amharic?
- [ ] Send '@main /cal next' in Dashboard Group -> Event list shown?
- [ ] Send '/task add Test' in Dashboard Group -> Task ID returned?
EOF

echo -e "\n=========================================================="
echo "               VERIFICATION COMPLETE                      "
echo "=========================================================="
echo "Report generated: ${REPORT_FILE}"
