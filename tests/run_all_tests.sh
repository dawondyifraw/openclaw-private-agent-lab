#!/bin/bash
# tests/run_all_tests.sh
# Main entrypoint for the OpenClaw E2E Verification Suite.

set -e

BASE_DIR="/home/devbox/.openclaw"
DOCS_DIR="${BASE_DIR}/docs"
REPORT_FILE="${DOCS_DIR}/VERIFICATION_REPORT.md"
mkdir -p "${DOCS_DIR}"

# Canonical workspace root (plural). Tests should use this instead of hardcoding workspace paths.
export OPENCLAW_WORKSPACES_ROOT="${OPENCLAW_WORKSPACES_ROOT:-${BASE_DIR}/workspaces}"

OPENCLAW_TEST_MODE="${OPENCLAW_TEST_MODE:-default}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================================="
echo "      OPENCLAW E2E SYSTEM VERIFICATION                    "
echo "=========================================================="
echo "Test mode: ${OPENCLAW_TEST_MODE}"

# Header for Report
cat <<EOF > "${REPORT_FILE}"
# OpenClaw System Verification Report
**Date:** $(date)
**System Version:** $(openclaw --version 2>/dev/null || echo "2026.2.6-3")
**Test Mode:** ${OPENCLAW_TEST_MODE}

## Summary Results
| Module | Status | Details |
|--------|--------|---------|
EOF

RESULTS_TABLE=""
FAIL_COUNT=0

run_test() {
    local name=$1
    local script=$2
    echo -n "Running $name... "
    set +e
    OUTPUT=$(bash "$script" 2>&1)
    EXIT_CODE=$?
    set -e
    
    if [ $EXIT_CODE -eq 0 ]; then
        # Allow "EXPECTED_FAIL" without failing the suite (e.g., optional providers in strict).
        if echo "$OUTPUT" | rg -q "EXPECTED_FAIL"; then
            echo -e "${YELLOW}EXPECTED_FAIL${NC}"
            RESULTS_TABLE+="| $name | EXPECTED_FAIL | See Evidence Section |"$'\n'
        else
            echo -e "${GREEN}PASS${NC}"
            RESULTS_TABLE+="| $name | PASS | - |"$'\n'
        fi
    else
        echo -e "${RED}FAIL${NC}"
        RESULTS_TABLE+="| $name | FAIL | See Evidence Section |"$'\n'
        FAIL_COUNT=$((FAIL_COUNT + 1))
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

# 2.1 Workspace Root
run_test "Workspace Root" "${BASE_DIR}/tests/test_workspace_root.sh"

# 3. Allowlist
run_test "Telegram Allowlist" "${BASE_DIR}/tests/test_allowlist.sh"

# 3.1 Telegram Outbound Sanitizer Presence (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_telegram_outbound_sanitizer_present.sh" ]; then
    run_test "Telegram Sanitizer Present" "${BASE_DIR}/tests/test_telegram_outbound_sanitizer_present.sh"
fi

# 4. Agent Auth Sync
run_test "Agent Auth Sync" "${BASE_DIR}/tests/test_agent_auth_sync.sh"

# 4.1 Agent Tool/Prompt Consistency (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_agent_tool_consistency.sh" ]; then
    run_test "Agent Tool Consistency" "${BASE_DIR}/tests/test_agent_tool_consistency.sh"
fi

# 5. Ollama
run_test "Ollama Local" "${BASE_DIR}/tests/test_ollama.sh"

# 6. GPU Usage
run_test "GPU Utilization" "${BASE_DIR}/tests/test_gpu.sh"

# 7. OpenRouter
run_test "OpenRouter Provider" "${BASE_DIR}/tests/test_openrouter.sh"

# 7.1 Groq
if [ -f "${BASE_DIR}/tests/test_groq_provider.sh" ]; then
    run_test "Groq Provider" "${BASE_DIR}/tests/test_groq_provider.sh"
fi

# 8. Google Provider
run_test "Google Provider" "${BASE_DIR}/tests/test_google_provider.sh"

# 8.1 Kimi Provider (disabled/non-blocking)
if [ -f "${BASE_DIR}/tests/test_kimi_coding.sh" ]; then
    run_test "Kimi Provider" "${BASE_DIR}/tests/test_kimi_coding.sh"
fi

# 8.2 Minimax Provider (disabled/non-blocking)
if [ -f "${BASE_DIR}/tests/test_minimax_provider.sh" ]; then
    run_test "Minimax Provider" "${BASE_DIR}/tests/test_minimax_provider.sh"
fi

# 9. Calendar
run_test "Calendar Service" "${BASE_DIR}/tests/test_calendar.sh"

# 10. RAG
run_test "RAG Pipeline" "${BASE_DIR}/tests/test_rag.sh"

# 11. Dashboard
run_test "Dashboard Skill" "${BASE_DIR}/tests/test_dashboard.sh"

# 11.1 Main Failover Proof (strict only)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_main_failover.sh" ]; then
    run_test "Main Failover" "${BASE_DIR}/tests/test_main_failover.sh"
fi

# 11.2 Fallback under cooldown (strict only)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_fallback_under_cooldown.sh" ]; then
    run_test "Fallback Under Cooldown" "${BASE_DIR}/tests/test_fallback_under_cooldown.sh"
fi

# 12. Sandbox Tool Runner
if [ -f "${BASE_DIR}/tests/test_sandbox_runner.sh" ]; then
    run_test "Sandbox Runner" "${BASE_DIR}/tests/test_sandbox_runner.sh"
fi

# 12. Memory Isolation
if [ -f "${BASE_DIR}/tests/test_memory_isolation.sh" ]; then
    run_test "Memory Isolation" "${BASE_DIR}/tests/test_memory_isolation.sh"

    # 13. Telegram Configuration
    run_test "Telegram Config" "${BASE_DIR}/tests/test_telegram_config.sh"

# 14. Telegram Logs
    run_test "Telegram Behavior" "${BASE_DIR}/tests/test_telegram_logs.sh"
fi

# 14.1 Forbidden Tool Calls In Recent Telegram Sessions (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_recent_forbidden_toolcalls.sh" ]; then
    run_test "Recent Forbidden ToolCalls" "${BASE_DIR}/tests/test_recent_forbidden_toolcalls.sh"
fi

# 14.2 Telegram Internal Leak Markers (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_telegram_internal_leakage_markers.sh" ]; then
    run_test "Telegram Internal Leak Markers" "${BASE_DIR}/tests/test_telegram_internal_leakage_markers.sh"
fi

# 14.3 Telegram Sanitizer Telemetry Presence (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_telegram_sanitizer_telemetry.sh" ]; then
    run_test "Telegram Sanitizer Telemetry" "${BASE_DIR}/tests/test_telegram_sanitizer_telemetry.sh"
fi

# 14.4 Telegram No-Leak Logs (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_telegram_no_leak_in_logs.sh" ]; then
    run_test "Telegram No-Leak Logs" "${BASE_DIR}/tests/test_telegram_no_leak_in_logs.sh"
fi

# 14.5 Commands No-LLM Guard (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_commands_no_llm.sh" ]; then
    run_test "Commands No LLM" "${BASE_DIR}/tests/test_commands_no_llm.sh"
fi

# 14.6 Provider guard for /model(s) switches (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_models_provider_guard.sh" ]; then
    run_test "Models Provider Guard" "${BASE_DIR}/tests/test_models_provider_guard.sh"
fi

# 14.7 No disallowed tool calls in non-main Telegram sessions (strict)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_no_tools_in_nonmain_telegram.sh" ]; then
    run_test "No Tools In Non-Main Telegram" "${BASE_DIR}/tests/test_no_tools_in_nonmain_telegram.sh"
fi

# 14.8 Telegram language policy (strict, best-effort when recent traffic exists)
if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ -f "${BASE_DIR}/tests/test_telegram_language_policy.sh" ]; then
    run_test "Telegram Language Policy" "${BASE_DIR}/tests/test_telegram_language_policy.sh"
fi

# 15. Tool Leakage Guard
if [ -f "${BASE_DIR}/tests/test_tool_leakage.sh" ]; then
    run_test "Tool Leakage" "${BASE_DIR}/tests/test_tool_leakage.sh"
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

if [ "${OPENCLAW_TEST_MODE}" = "strict" ] && [ "${FAIL_COUNT}" -gt 0 ]; then
    echo "STRICT MODE: failing due to ${FAIL_COUNT} failed module(s)."
    exit 1
fi
