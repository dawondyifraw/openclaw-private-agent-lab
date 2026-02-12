#!/usr/bin/env python3
import os
import json
import time
import requests

ENV_PATH = "/home/devbox/.openclaw/.env"

KIMI_DEFAULT_HOSTS = [
    "https://api.moonshot.cn/v1",
    "https://api.moonshot.ai/v1",
]


def load_env(path: str) -> dict:
    env_vars: dict[str, str] = {}
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                env_vars[k.strip()] = v.strip().strip("'\"")
    return env_vars


def collect_keys() -> dict:
    """
    Reads keys from process env and/or ~/.openclaw/.env.

    Supported:
    - KIMI_API_KEYS="k1,k2,..." (comma-separated) OR KIMI_API_KEY[_N]
    - GOOGLE_API_KEY
    - GROQ_API_KEY
    - OPENROUTER_API_KEY
    - OPENAI_API_KEY
    - MINIMAX_API_KEY
    """
    env_file = load_env(ENV_PATH)

    def get(name: str) -> str | None:
        return os.environ.get(name) or env_file.get(name)

    keys: dict[str, str] = {}

    # Kimi: multiple keys are common for rotation/testing
    kimi_list = get("KIMI_API_KEYS")
    if kimi_list:
        for i, k in enumerate([x.strip() for x in kimi_list.split(",") if x.strip()], start=1):
            keys[f"KIMI_{i}"] = k
    else:
        base = get("KIMI_API_KEY")
        if base:
            keys["KIMI_1"] = base
        for i in range(2, 51):
            v = get(f"KIMI_API_KEY_{i}")
            if v:
                keys[f"KIMI_{i}"] = v

    if get("OPENAI_API_KEY"):
        keys["OPENAI"] = get("OPENAI_API_KEY")  # type: ignore[assignment]
    if get("GOOGLE_API_KEY"):
        keys["GEMINI"] = get("GOOGLE_API_KEY")  # type: ignore[assignment]
    if get("GROQ_API_KEY"):
        keys["GROQ"] = get("GROQ_API_KEY")  # type: ignore[assignment]
    if get("OPENROUTER_API_KEY"):
        keys["OPENROUTER"] = get("OPENROUTER_API_KEY")  # type: ignore[assignment]
    if get("MINIMAX_API_KEY"):
        keys["MINIMAX"] = get("MINIMAX_API_KEY")  # type: ignore[assignment]

    return keys


def _rate_headers(headers: dict) -> dict:
    return {k: v for k, v in headers.items() if "rate" in k.lower() or "limit" in k.lower() or "retry" in k.lower()}


def _normalize_base_url(base: str) -> str:
    base = (base or "").strip().rstrip("/")
    if base.endswith("/chat/completions"):
        base = base[: -len("/chat/completions")]
    if not base.endswith("/v1"):
        base = base + "/v1"
    return base


def test_openai_compatible(name: str, key: str, url: str, model: str) -> bool:
    print(f"Testing {name}...")
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    data = {"model": model, "messages": [{"role": "user", "content": "Reply with exactly: OK"}], "temperature": 0, "max_tokens": 5}
    try:
        resp = requests.post(url, headers=headers, json=data, timeout=30)
        if resp.status_code == 200:
            out = resp.json()["choices"][0]["message"]["content"].strip()
            print(f"  🟢 {name} PASS (content={out!r})")
            return True
        else:
            print(f"  🔴 {name} FAIL: {resp.status_code} - {(resp.text or '')[:200]}")
            return False
    except Exception as e:
        print(f"  🔴 {name} ERROR: {e}")
        return False


def test_kimi_detailed(key: str) -> bool:
    print("Testing KIMI (Moonshot) [detailed]...")

    base_override = os.environ.get("KIMI_BASE_URL")
    if base_override:
        bases = [_normalize_base_url(base_override)]
    else:
        bases = [_normalize_base_url(b) for b in KIMI_DEFAULT_HOSTS]

    model_override = os.environ.get("KIMI_MODEL", "k2p5")
    candidate_models = [model_override, "moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"]

    sess = requests.Session()
    sess.headers.update({"Authorization": f"Bearer {key}", "Content-Type": "application/json"})

    for base in bases:
        print(f"  Base: {base}")

        models: list[str] = []
        try:
            r = sess.get(base + "/models", timeout=20)
            print(f"  GET /models -> {r.status_code}")
            rh = _rate_headers(r.headers)
            if rh:
                print("   rate:", json.dumps(rh, sort_keys=True))
            if r.status_code == 200:
                j = r.json()
                models = [d.get("id") for d in (j.get("data") or []) if isinstance(d, dict) and d.get("id")]
                print(f"   models: {len(models)} (first: {', '.join(models[:6])})")
            else:
                print(f"   body: {(r.text or '')[:200].replace('\\n', ' ')}")
        except Exception as e:
            print(f"  GET /models -> ERROR: {e}")

        to_try: list[str]
        if models:
            to_try = ([model_override] if model_override in models else []) + models[:3]
        else:
            to_try = candidate_models

        for model in to_try:
            payload = {
                "model": model,
                "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
                "temperature": 0,
                "max_tokens": 5,
            }
            try:
                r = sess.post(base + "/chat/completions", json=payload, timeout=30)
                print(f"  POST /chat/completions model={model} -> {r.status_code}")
                rh = _rate_headers(r.headers)
                if rh:
                    print("   rate:", json.dumps(rh, sort_keys=True))
                if r.status_code == 200:
                    out = r.json()["choices"][0]["message"]["content"].strip()
                    print(f"   content: {out!r}")
                    return True
                else:
                    body = (r.text or "")[:200].replace("\n", " ")
                    print(f"   body: {body}")
                    if r.status_code == 401:
                        print("   hint: 401 usually means the API key is invalid/revoked or not accepted for this API.")
                    elif r.status_code == 404:
                        print("   hint: 404 usually means the base URL is wrong (missing /v1) or the endpoint path is incorrect.")
                    elif r.status_code == 429:
                        print("   hint: 429 means rate limited; tests may be flaky without backoff/retry.")
            except Exception as e:
                print(f"  POST /chat/completions model={model} -> ERROR: {e}")

    return False


def test_gemini(key: str) -> bool:
    print("Testing GEMINI...")
    url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    data = {"model": "gpt-3.5-turbo", "messages": [{"role": "user", "content": "Reply with exactly: OK"}], "temperature": 0, "max_tokens": 5}
    try:
        resp = requests.post(url, headers=headers, json=data, timeout=30)
        if resp.status_code == 200:
            print("  🟢 GEMINI PASS")
            return True
        print(f"  🔴 GEMINI FAIL: {resp.status_code} - {(resp.text or '')[:200]}")
        return False
    except Exception as e:
        print(f"  🔴 GEMINI ERROR: {e}")
        return False


def test_openrouter(key: str) -> bool:
    print("Testing OPENROUTER...")
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json", "HTTP-Referer": "https://openclaw.io"}
    data = {"model": "google/gemini-2.0-flash-001", "messages": [{"role": "user", "content": "Reply with exactly: OK"}], "temperature": 0, "max_tokens": 5}
    try:
        resp = requests.post(url, headers=headers, json=data, timeout=30)
        if resp.status_code == 200:
            print("  🟢 OPENROUTER PASS")
            return True
        print(f"  🔴 OPENROUTER FAIL: {resp.status_code} - {(resp.text or '')[:200]}")
        return False
    except Exception as e:
        print(f"  🔴 OPENROUTER ERROR: {e}")
        return False


def main() -> None:
    keys = collect_keys()
    if not keys:
        print(f"No API keys found via env or {ENV_PATH}.")
        return

    results: dict[str, bool] = {}

    # KIMI tests: run all detected KIMI_* keys (no hardcoded list)
    kimi_names = sorted([k for k in keys.keys() if k.startswith("KIMI_")])
    for kname in kimi_names:
        results[kname] = test_kimi_detailed(keys[kname])
        time.sleep(0.8)

    # Other providers (optional)
    if "OPENAI" in keys:
        results["OPENAI"] = test_openai_compatible("OPENAI", keys["OPENAI"], "https://api.openai.com/v1/chat/completions", "gpt-3.5-turbo")
    if "GROQ" in keys:
        results["GROQ"] = test_openai_compatible("GROQ", keys["GROQ"], "https://api.groq.com/openai/v1/chat/completions", "llama-3.3-70b-versatile")
    if "MINIMAX" in keys:
        results["MINIMAX"] = test_openai_compatible("MINIMAX", keys["MINIMAX"], "https://api.minimax.chat/v1/text_chat", "abab6.5-chat")
    if "GEMINI" in keys:
        results["GEMINI"] = test_gemini(keys["GEMINI"])
    if "OPENROUTER" in keys:
        results["OPENROUTER"] = test_openrouter(keys["OPENROUTER"])

    print("\n" + "=" * 40)
    print("FINAL SUMMARY")
    print("=" * 40)
    for k, v in results.items():
        print(f"{k:15}: {'✅ WORKING' if v else '❌ FAILED'}")


if __name__ == "__main__":
    main()

