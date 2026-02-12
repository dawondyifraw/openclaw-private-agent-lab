#!/usr/bin/env python3
import os
import requests
import json

# Path to the .env file
ENV_PATH = "/home/devbox/.openclaw/.env"

def load_env(path):
    env_vars = {}
    if os.path.exists(path):
        with open(path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    # Remove quotes if present
                    value = value.strip("'\"")
                    env_vars[key] = value
    return env_vars

def test_google(key):
    print("Testing Google (Gemini)...")
    url = f"https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    data = {
        "model": "gemini-2.5-flash", # Gemini handles OpenAI format
        "messages": [{"role": "user", "content": "hi"}]
    }
    try:
        resp = requests.post(url, headers=headers, json=data, timeout=10)
        if resp.status_code == 200:
            print("  🟢 PASS: Connection successful.")
        else:
            print(f"  🔴 FAIL: HTTP {resp.status_code} - {resp.text}")
    except Exception as e:
        print(f"  🔴 ERROR: {str(e)}")

def test_kimi(key):
    print("Testing Kimi (Moonshot / kimi-coding)...")
    # Align with OpenClaw provider config (agents/main/agent/models.json):
    # baseUrl: https://api.moonshot.cn/v1
    url = os.environ.get("KIMI_BASE_URL", "https://api.moonshot.cn/v1").rstrip("/") + "/chat/completions"
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    data = {
        # Align with OpenClaw's configured kimi-coding model id (agents/main/agent/agent.yaml).
        # Override for troubleshooting if needed.
        "model": os.environ.get("KIMI_MODEL", "k2p5"),
        "messages": [{"role": "user", "content": "hi"}]
    }
    try:
        resp = requests.post(url, headers=headers, json=data, timeout=10)
        if resp.status_code == 200:
            print("  🟢 PASS: Connection successful.")
        else:
            print(f"  🔴 FAIL: HTTP {resp.status_code} - {resp.text}")
    except Exception as e:
        print(f"  🔴 ERROR: {str(e)}")

def test_groq(key):
    print("Testing Groq...")
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    data = {
        "model": "llama-3.3-70b-versatile",
        "messages": [{"role": "user", "content": "hi"}]
    }
    try:
        resp = requests.post(url, headers=headers, json=data, timeout=10)
        if resp.status_code == 200:
            print("  🟢 PASS: Connection successful.")
        else:
            print(f"  🔴 FAIL: HTTP {resp.status_code} - {resp.text}")
    except Exception as e:
        print(f"  🔴 ERROR: {str(e)}")

def test_openrouter(key):
    print("Testing OpenRouter...")
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://openclaw.io"
    }
    data = {
        "model": "google/gemini-2.0-flash-001",
        "messages": [{"role": "user", "content": "hi"}]
    }
    try:
        resp = requests.post(url, headers=headers, json=data, timeout=10)
        if resp.status_code == 200:
            print("  🟢 PASS: Connection successful.")
        else:
            print(f"  🔴 FAIL: HTTP {resp.status_code} - {resp.text}")
    except Exception as e:
        print(f"  🔴 ERROR: {str(e)}")

def main():
    env = load_env(ENV_PATH)
    
    keys_to_test = {
        "GOOGLE_API_KEY": test_google,
        "KIMI_API_KEY": test_kimi,
        "GROQ_API_KEY": test_groq,
        "OPENROUTER_API_KEY": test_openrouter
    }
    
    print(f"--- API Key Connectivity Audit ({ENV_PATH}) ---")
    for env_key, test_func in keys_to_test.items():
        val = env.get(env_key)
        if val:
            test_func(val)
        else:
            print(f"{env_key}: ⚪ NOT FOUND in .env")
        print("-" * 40)

if __name__ == "__main__":
    main()
