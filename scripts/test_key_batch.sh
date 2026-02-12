#!/usr/bin/env bash
set -euo pipefail

# API key tester using .env as source of truth.
# Supported providers: google, openrouter, groq, mistral, openai

ROOT_DIR="/home/devbox/.openclaw"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-20}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required."
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo ".env file not found: ${ENV_FILE}"
  exit 1
fi

mask_key() {
  local key="$1"
  local n="${#key}"
  if (( n <= 8 )); then
    printf "***"
  else
    printf "%s***%s" "${key:0:4}" "${key:n-4:4}"
  fi
}

provider_endpoint() {
  local provider="$1"
  case "${provider}" in
    google)
      echo "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions|gemini-2.5-flash"
      ;;
    openrouter)
      echo "https://openrouter.ai/api/v1/chat/completions|google/gemini-2.0-flash-001"
      ;;
    groq)
      echo "https://api.groq.com/openai/v1/chat/completions|llama-3.3-70b-versatile"
      ;;
    mistral)
      echo "https://api.mistral.ai/v1/chat/completions|mistral-large-2411"
      ;;
    openai)
      echo "https://api.openai.com/v1/chat/completions|gpt-4o-mini"
      ;;
    *)
      return 1
      ;;
  esac
}

env_get() {
  local name="$1"
  local from_env="${!name-}"
  if [[ -n "${from_env}" ]]; then
    printf "%s" "${from_env}"
    return 0
  fi
  local v
  v="$(grep -E "^[[:space:]]*${name}=" "${ENV_FILE}" | head -n 1 | cut -d '=' -f2- | sed "s/^[[:space:]]*//; s/[[:space:]]*$//; s/^['\\\"]//; s/['\\\"]$//")"
  printf "%s" "${v}"
}

run_probe() {
  local provider="$1"
  local key="$2"
  local meta
  local url
  local model
  local code
  local payload
  local tmp
  local key_masked

  if ! meta="$(provider_endpoint "${provider}")"; then
    echo "[$(printf '%-10s' "${provider}")] SKIP unsupported provider"
    return 2
  fi

  IFS='|' read -r url model <<< "${meta}"
  key_masked="$(mask_key "${key}")"
  tmp="$(mktemp)"
  payload="$(jq -cn --arg m "${model}" '{model:$m,messages:[{role:"user",content:"Reply with exactly: OK"}],temperature:0,max_tokens:6}')"

  if [[ "${provider}" == "openrouter" ]]; then
    code="$(curl -sS -o "${tmp}" -w "%{http_code}" -m "${TIMEOUT_SECONDS}" \
      -X POST "${url}" \
      -H "Authorization: Bearer ${key}" \
      -H "Content-Type: application/json" \
      -H "HTTP-Referer: https://openclaw.local" \
      -H "X-Title: openclaw-key-batch-test" \
      -d "${payload}" || true)"
  else
    code="$(curl -sS -o "${tmp}" -w "%{http_code}" -m "${TIMEOUT_SECONDS}" \
      -X POST "${url}" \
      -H "Authorization: Bearer ${key}" \
      -H "Content-Type: application/json" \
      -d "${payload}" || true)"
  fi

  if [[ "${code}" == "200" ]] && jq -e '.choices | type=="array" and length>0' "${tmp}" >/dev/null 2>&1; then
    echo "[$(printf '%-10s' "${provider}")] PASS key=${key_masked} endpoint=${url}"
    rm -f "${tmp}"
    return 0
  fi

  local err
  err="$(jq -r '.error.message // .message // .error // empty' "${tmp}" 2>/dev/null || true)"
  if [[ -z "${err}" ]]; then
    err="$(head -c 220 "${tmp}" | tr '\n' ' ')"
  fi
  echo "[$(printf '%-10s' "${provider}")] FAIL key=${key_masked} http=${code} endpoint=${url} msg=${err}"
  rm -f "${tmp}"
  return 1
}

run_provider_if_present() {
  local provider="$1"
  local key_var="$2"
  local key
  key="$(env_get "${key_var}")"
  if [[ -z "${key}" ]]; then
    echo "[$(printf '%-10s' "${provider}")] SKIP ${key_var} not set"
    ((skip+=1))
    return 0
  fi

  ((total+=1))
  if run_probe "${provider}" "${key}"; then
    ((pass+=1))
  else
    rc=$?
    if [[ "${rc}" -eq 2 ]]; then
      ((skip+=1))
    else
      ((fail+=1))
    fi
  fi
}

echo "Key source: ${ENV_FILE}"
echo "Supported providers: google, openrouter, groq, mistral, openai"
echo

total=0
pass=0
fail=0
skip=0

run_provider_if_present "google" "GOOGLE_API_KEY"
run_provider_if_present "openrouter" "OPENROUTER_API_KEY"
run_provider_if_present "groq" "GROQ_API_KEY"
run_provider_if_present "mistral" "MISTRAL_API_KEY"
run_provider_if_present "openai" "OPENAI_API_KEY"

echo
echo "Summary: total=${total} pass=${pass} fail=${fail} skip=${skip}"
[[ "${fail}" -eq 0 ]]
