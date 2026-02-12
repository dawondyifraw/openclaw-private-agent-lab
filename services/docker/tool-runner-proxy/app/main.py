from __future__ import annotations

import json
import os
import re
import uuid
from pathlib import Path
from typing import Any, Literal
from urllib.parse import urlparse

import httpx
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field


APP_VERSION = "0.1.1"

ALLOWED_TOOLS = {"file_read", "file_write", "shell_exec"}
ALLOWED_BINARIES = {"curl", "python3", "python", "pytest"}
ALLOWED_INTERNAL_HOSTS = {"ollama", "rag-service"}

AGENT_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")


def _required_env(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        raise RuntimeError(f"missing required env: {name}")
    return v


def _require_guard_token(auth: str | None) -> None:
    expected = _required_env("SANDBOX_GUARD_TOKEN")
    if not auth or not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing auth")
    tok = auth.split(" ", 1)[1].strip()
    if tok != expected:
        raise HTTPException(status_code=401, detail="invalid auth")


def _load_allowlist() -> set[tuple[str, str]]:
    path = Path(_required_env("ALLOWLIST_PATH"))
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        raise RuntimeError("failed to read allowlist")

    allowed: set[tuple[str, str]] = set()
    for row in obj.get("telegram", []):
        if not isinstance(row, dict):
            continue
        agent = row.get("agent")
        chat_id = row.get("chat_id")
        if isinstance(agent, str) and isinstance(chat_id, str):
            allowed.add((agent, chat_id))
    return allowed


def _enforce_allowlist(allowed: set[tuple[str, str]], agent: str, chat_id: str) -> None:
    if not AGENT_RE.match(agent or ""):
        raise HTTPException(status_code=400, detail="invalid agent")
    if not chat_id:
        raise HTTPException(status_code=400, detail="missing chat_id")
    if (agent, chat_id) not in allowed:
        raise HTTPException(status_code=403, detail="agent/scope not allowed")


def _clamp_timeout_s(x: Any, default: int = 10) -> int:
    try:
        v = int(x)
    except Exception:
        v = default
    return max(1, min(v, 60))


def _curl_internal_host(cmd: list[str]) -> str | None:
    # Minimal parsing: find first non-flag token after "curl" as URL.
    if len(cmd) < 2:
        return None
    allowed_flags = {"-f", "-s", "-S", "-fsS", "-m"}
    i = 1
    while i < len(cmd):
        tok = cmd[i]
        if tok.startswith("-"):
            if tok not in allowed_flags:
                raise HTTPException(status_code=403, detail=f"curl flag not allowed: {tok}")
            if tok == "-m":
                if i + 1 >= len(cmd):
                    raise HTTPException(status_code=400, detail="curl -m requires seconds")
                i += 2
                continue
            i += 1
            continue
        url = tok
        parsed = urlparse(url)
        host = parsed.hostname
        if parsed.scheme not in ("http", "https") or not host:
            raise HTTPException(status_code=403, detail="curl URL must be http(s) with hostname")
        return host
    return None


class Scope(BaseModel):
    type: Literal["telegram"]
    chat_id: str
    user_id: str | None = None


class RunRequest(BaseModel):
    request_id: str | None = None
    agent: str
    scope: Scope
    tool: str
    args: dict[str, Any] = Field(default_factory=dict)
    # Ignore any caller-supplied policy; guard enforces server-side.
    policy: dict[str, Any] | None = None


class Artifact(BaseModel):
    path: str
    type: Literal["text", "file"]


class RunResponse(BaseModel):
    request_id: str
    ok: bool
    stdout: str = ""
    stderr: str = ""
    artifacts: list[Artifact] = Field(default_factory=list)
    error: str | None = None


app = FastAPI(title="OpenClaw Sandbox Guard", version=APP_VERSION)

# Load once at startup; changes require container restart (intentional).
ALLOWLIST = _load_allowlist()


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "version": APP_VERSION, "allowed_pairs": len(ALLOWLIST)}


@app.post("/run", response_model=RunResponse)
async def run(req: RunRequest, authorization: str | None = Header(default=None)) -> RunResponse:
    _require_guard_token(authorization)

    request_id = req.request_id or str(uuid.uuid4())

    if req.tool not in ALLOWED_TOOLS:
        raise HTTPException(status_code=403, detail="tool not allowed")

    _enforce_allowlist(ALLOWLIST, req.agent, req.scope.chat_id)

    # Enforce tool-tier policies (caller cannot select fs/net/timeout).
    policy: dict[str, Any] = {"timeout_s": 10}

    if req.tool == "file_read":
        policy.update({"net_mode": "none", "net_allow": [], "timeout_s": 10})

        p = req.args.get("path")
        if not isinstance(p, str) or not p or p.startswith(("/", "\\")) or "\x00" in p:
            raise HTTPException(status_code=400, detail="invalid path")

    elif req.tool == "file_write":
        policy.update({"net_mode": "none", "net_allow": [], "timeout_s": 10})

        p = req.args.get("path")
        c = req.args.get("content")
        if not isinstance(p, str) or not p or p.startswith(("/", "\\")) or "\x00" in p:
            raise HTTPException(status_code=400, detail="invalid path")
        if not isinstance(c, str):
            raise HTTPException(status_code=400, detail="invalid content")
        if len(c.encode("utf-8")) > 2_000_000:
            raise HTTPException(status_code=413, detail="content too large")

    elif req.tool == "shell_exec":
        cmd = req.args.get("cmd")
        if not isinstance(cmd, list) or not cmd or not all(isinstance(x, str) for x in cmd):
            raise HTTPException(status_code=400, detail="invalid cmd")
        if cmd[0] in ("sh", "bash", "zsh", "fish"):
            raise HTTPException(status_code=403, detail="shell denied")
        if cmd[0] not in ALLOWED_BINARIES:
            raise HTTPException(status_code=403, detail="binary denied")

        # Default: no network. For curl, allowlist a specific internal host.
        if cmd[0] == "curl":
            host = _curl_internal_host(cmd)
            if not host or host not in ALLOWED_INTERNAL_HOSTS:
                raise HTTPException(status_code=403, detail="curl host not allowed")
            policy.update({"net_mode": "allowlist", "net_allow": [host]})
        else:
            policy.update({"net_mode": "none", "net_allow": []})

        policy["timeout_s"] = _clamp_timeout_s(req.args.get("timeout_s", 10), default=10)

    tool_runner_url = _required_env("TOOL_RUNNER_URL")
    tool_runner_token = _required_env("TOOL_RUNNER_TOKEN")

    payload = {
        "request_id": request_id,
        "agent": req.agent,
        "scope": req.scope.model_dump(),
        "tool": req.tool,
        "args": req.args,
        "policy": policy,
    }

    headers = {"Authorization": f"Bearer {tool_runner_token}"}

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            r = await client.post(tool_runner_url, json=payload, headers=headers)
        except Exception:
            raise HTTPException(status_code=502, detail="tool-runner unreachable")

    if r.status_code == 401:
        raise HTTPException(status_code=502, detail="tool-runner auth failed")

    if r.status_code >= 400:
        # Avoid leaking tool-runner internals.
        raise HTTPException(status_code=502, detail="tool-runner error")

    try:
        obj = r.json()
    except Exception:
        raise HTTPException(status_code=502, detail="tool-runner invalid response")

    # Return sanitized response object.
    return RunResponse(
        request_id=request_id,
        ok=bool(obj.get("ok", False)),
        stdout=str(obj.get("stdout", ""))[:80_000],
        stderr=str(obj.get("stderr", ""))[:80_000],
        artifacts=[Artifact(**a) for a in (obj.get("artifacts") or []) if isinstance(a, dict)],
        error=(None if obj.get("ok", False) else str(obj.get("error") or "failed")[:500]),
    )

