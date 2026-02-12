# Sandbox Tool Runner (v1.1)

This document describes the OpenClaw home-lab "Tier 1" tool execution sandbox that allows broader tool usage without granting any agent direct host execution privileges.

## Components

- `sandbox-guard` (host-exposed, trusted)
  - Reached via `sandbox-guard-proxy` on `http://localhost:18888`.
  - Enforces an explicit `(agent, chat_id)` allowlist.
  - Enforces tool-tier policies (fs/net/timeout). Caller-supplied policy is ignored.
  - Authenticates to `tool-runner` using a shared bearer token.

- `tool-runner` (internal-only, authenticated)
  - Not published on the host.
  - Accepts requests only with `Authorization: Bearer $TOOL_RUNNER_TOKEN`.
  - Spawns short-lived `runner-job` containers per request, with a bind mount ONLY for the computed workspace path.

- `runner-job` containers (untrusted execution boundary)
  - Run with `read_only` root filesystem, `cap_drop=ALL`, `no-new-privileges`, resource limits.
  - Mounts exactly one workspace at `/workspace` (RO by default; RW only for write tools).
  - Default network is `none`. For allowlisted internal curl calls, attaches to `sandbox_net` (internal-only) and still enforces a hostname allowlist.

## Threat Model (Practical)

Defended against:
- Cross-agent workspace reads/writes via mount scoping (real container boundary, not just path checks).
- Direct calls to internal tool-runner endpoints without auth (401).
- Caller attempts to force RW/network escalation via tool parameters (guard overrides; runner clamps).
- Tool output leakage of stack traces (job outputs JSON; errors are generic).

Not fully defended against (known limitation):
- If an attacker can call `sandbox-guard` with a valid `SANDBOX_GUARD_TOKEN`, they can choose any pair present in the allowlist file.
  - True agent identity derivation requires OpenClaw gateway integration (out of scope for this repo).
- `tool-runner` needs access to the Docker daemon socket to spawn job containers. If `tool-runner` is compromised, the Docker socket can be used to escape the sandbox.
  - Mitigation here is strict request authentication, strict input validation, and keeping `tool-runner` internal-only.

## Configuration

Required environment variables (set in `~/.openclaw/.env`, not committed):
- `SANDBOX_GUARD_TOKEN`: token required to call `sandbox-guard` (tool schema uses it).
- `TOOL_RUNNER_TOKEN`: internal token used by `sandbox-guard` to call `tool-runner`.

Allowlist:
- `services/docker/tool-runner-proxy/config/allowlist.json`
  - Contains allowed `(agent, chat_id)` pairs for Telegram scopes.

## How To Test

1. `docker compose up -d --build tool-runner sandbox-guard sandbox-guard-proxy`
2. Export the guard token for the test script:
   - `export SANDBOX_GUARD_TOKEN=REDACTED
3. Run:
   - `bash tests/test_sandbox_runner.sh`

The test suite covers:
- Guard health
- Workspace containment
- Spoof attempt denial (allowlist)
- Secrets path traversal denial
- No internet egress (blocked)
- Allowed internal egress to Ollama (allowlist + internal-only network)
- Tool-runner auth required (direct call without token -> 401)
- RW enforcement via RO mount for `shell_exec`
