#!/usr/bin/env bash
# OpenClaw Bootstrap Health Check (Non-destructive)

# ANSI escape codes for colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================================="
echo "      OPENCLAW BOOTSTRAP READINESS CHECK                  "
echo "=========================================================="

# 1. Docker Services Check
echo -n "Checking Docker Support Services... "
DOCKER_READY=true
for container in ollama chroma rag-service amharic-translation; do
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -ne "\n${RED}[MISSING]${NC} ${container}"
        DOCKER_READY=false
    fi
done

if [ "$DOCKER_READY" = true ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "\n${YELLOW}ACTION: Run 'docker compose up -d' to start support services.${NC}"
fi

# 2. Health Endpoints Check
if [ "$DOCKER_READY" = true ]; then
    echo -n "Checking Service Endpoints... "
    ENDPOINTS_READY=true
    
    # Ollama
    if ! curl -fsS http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -ne "\n${RED}[UNREACHABLE]${NC} Ollama (11434)"
        ENDPOINTS_READY=false
    fi
    
    # Chroma
    if ! curl -fsS http://localhost:8000/api/v2/heartbeat > /dev/null 2>&1; then
        echo -ne "\n${RED}[UNREACHABLE]${NC} Chroma (8000)"
        ENDPOINTS_READY=false
    fi
    
    # RAG
    if ! curl -fsS http://localhost:8811/health > /dev/null 2>&1; then
        echo -ne "\n${RED}[UNREACHABLE]${NC} RAG Service (8811)"
        ENDPOINTS_READY=false
    fi
    
    # Amharic
    if ! curl -fsS http://localhost:18790/health > /dev/null 2>&1; then
        echo -ne "\n${RED}[UNREACHABLE]${NC} Amharic Service (18790)"
        ENDPOINTS_READY=false
    fi

    # Calendar
    if ! curl -fsS http://localhost:18821/health > /dev/null 2>&1; then
        echo -ne "\n${RED}[UNREACHABLE]${NC} Calendar Service (18821)"
        ENDPOINTS_READY=false
    fi

    # Dashboard
    if ! curl -fsS http://localhost:18820/health > /dev/null 2>&1; then
        echo -ne "\n${RED}[UNREACHABLE]${NC} Dashboard Service (18820)"
        ENDPOINTS_READY=false
    fi

    if [ "$ENDPOINTS_READY" = true ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "\n${YELLOW}ACTION: Check Docker logs for unreachable services.${NC}"
    fi
fi

# 3. Google Gemini Connectivity Check
echo -n "Checking Google Gemini Connectivity... "
if [ -n "$GOOGLE_API_KEY" ]; then
    G_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GOOGLE_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"contents":[{"parts":[{"text":"ping"}]}]}')
    if [ "$G_STATUS" == "200" ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL (HTTP $G_STATUS)${NC}"
        echo -e "${YELLOW}WARNING: Main agent will fall back to Kimi.${NC}"
    fi
else
    echo -e "${RED}MISSING GOOGLE_API_KEY${NC}"
fi

# 4. OpenRouter Connectivity Check
echo -n "Checking OpenRouter Connectivity... "
if [ -n "$OPENROUTER_API_KEY" ]; then
    OR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "https://openrouter.ai/api/v1/models" \
        -H "Authorization: Bearer ${OPENROUTER_API_KEY}")
    if [ "$OR_STATUS" == "200" ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL (HTTP $OR_STATUS)${NC}"
    fi
else
    echo -e "${RED}MISSING OPENROUTER_API_KEY${NC}"
fi

# 5. Auth Profile Sync Check
echo -n "Checking Auth Profile Sync... "
SYNCCED=true
for agent in main anxietychat assistant g-coder g-hello g-moltd merry-bot; do
    if [ ! -f "/home/devbox/.openclaw/agents/$agent/agent/auth-profiles.json" ]; then
        echo -ne "\n${RED}[MISSING]${NC} $agent/auth-profiles.json"
        SYNCCED=false
    fi
done
if [ "$SYNCCED" = true ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "\n${YELLOW}ACTION: Run 'bash scripts/sync_auth_profiles.sh'${NC}"
fi

# 6. Systemd Service Check
echo -n "Checking OpenClaw Systemd Service... "
if systemctl --user is-active openclaw-gateway.service > /dev/null 2>&1; then
    echo -e "${GREEN}ACTIVE${NC}"
else
    echo -e "${YELLOW}INACTIVE${NC}"
    echo -e "${YELLOW}NOTE: It is recommended to run 'bash tests/run_all_tests.sh' before starting the service.${NC}"
fi

echo -e "\n=========================================================="
if [ "$DOCKER_READY" = true ] && [ "$ENDPOINTS_READY" = true ]; then
    echo -e "${GREEN}SYSTEM READY FOR CORE BOOTSTRAP${NC}"
else
    echo -e "${RED}SYSTEM NOT READY - RESOLVE MISSING SERVICES${NC}"
fi
echo "=========================================================="
