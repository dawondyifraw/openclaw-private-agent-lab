# System E2E Report (Reproducible)

Date: 2026-02-11  
Live root: `/home/devbox/.openclaw`  
Primary command: `OPENCLAW_TEST_MODE=strict bash /home/devbox/.openclaw/tests/run_all_tests.sh`

## Reproducible Validation Steps

1. Run strict test suite:
```bash
cd /home/devbox/.openclaw
OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh
```

2. Verify gateway live root anchoring:
```bash
systemctl --user cat openclaw-gateway.service
```
Expect only `/home/devbox/.openclaw` runtime paths in `EnvironmentFile` and related settings.

3. Verify support plane health:
```bash
curl -fsS http://localhost:11434/api/tags
curl -fsS http://localhost:8811/health
curl -fsS http://localhost:8000/api/v2/heartbeat
curl -fsS http://localhost:18790/health
curl -fsS http://localhost:18888/health
```

4. Verify Telegram config policy-as-code:
```bash
OPENCLAW_TEST_MODE=strict bash tests/test_allowlist.sh
OPENCLAW_TEST_MODE=strict bash tests/test_telegram_config.sh
```

5. Verify sandbox auth and containment:
```bash
OPENCLAW_TEST_MODE=strict bash tests/test_sandbox_runner.sh
```

6. Verify provider chain and failover proof:
```bash
OPENCLAW_TEST_MODE=strict bash tests/test_openrouter.sh
OPENCLAW_TEST_MODE=strict bash tests/test_groq_provider.sh
OPENCLAW_TEST_MODE=strict bash tests/test_main_failover.sh
```

## Current Strict Reality
- Required healthy providers in strict: OpenRouter + Groq.
- Optional provider behavior in strict: Google Gemini may be `EXPECTED_FAIL` without failing the full suite.
- Telegram leakage checks are strict-gated and expected to pass when sanitizer markers and no-leak scans pass.

## Output Artifacts
- Full generated run output: `docs/VERIFICATION_REPORT.md`
- Beginner bootstrap guide: `docs/BOOTSTRAP_BEGINNER.md`
- Persona runtime/template status: `docs/PERSONA_STATUS.md`
