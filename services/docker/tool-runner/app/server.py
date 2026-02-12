from __future__ import annotations

import json
import uuid
from typing import Any, Literal

import docker
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from .common import (
    ALLOWED_INTERNAL_HOSTS,
    ALLOWED_TOOLS,
    EffectivePolicy,
    b64json_dumps,
    get_required_env,
    validate_agent_scope,
    workspace_key,
)

APP_VERSION = "0.1.1"


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
    # NOTE: policy is accepted only from sandbox-guard; callers should not send it directly.
    policy: dict[str, Any] = Field(default_factory=dict)


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


def _require_token(auth: str | None) -> None:
    expected = get_required_env("TOOL_RUNNER_TOKEN")
    if not auth or not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing auth")
    token = auth.split(" ", 1)[1].strip()
    if token != expected:
        raise HTTPException(status_code=401, detail="invalid auth")


def _effective_policy(req: RunRequest) -> EffectivePolicy:
    # Defense-in-depth: clamp even if guard misbehaves.
    tool = req.tool
    if tool == "file_read":
        return EffectivePolicy(fs_mode="ro", net_mode="none", net_allow=set(), timeout_s=10)
    if tool == "file_write":
        return EffectivePolicy(fs_mode="rw", net_mode="none", net_allow=set(), timeout_s=10)
    if tool == "shell_exec":
        # Default no network unless explicitly allowlisted by guard for curl.
        net_mode: Literal["none", "allowlist"] = "none"
        net_allow: set[str] = set()
        p = req.policy or {}
        if p.get("net_mode") == "allowlist":
            allow = set(p.get("net_allow") or [])
            if allow - ALLOWED_INTERNAL_HOSTS:
                raise HTTPException(status_code=403, detail="forbidden net_allow")
            net_mode = "allowlist"
            net_allow = allow
        timeout_s = int(p.get("timeout_s", 10))
        timeout_s = max(1, min(timeout_s, 60))
        return EffectivePolicy(fs_mode="ro", net_mode=net_mode, net_allow=net_allow, timeout_s=timeout_s)
    raise HTTPException(status_code=403, detail="tool not allowed")


def _host_workspace_path(agent: str, scope: Scope) -> str:
    host_root = get_required_env("HOST_WORKSPACES_ROOT")
    key = workspace_key(scope.model_dump())
    return f"{host_root}/{agent}/{key}"


app = FastAPI(title="OpenClaw Tool Runner", version=APP_VERSION)


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "version": APP_VERSION, "tools": sorted(ALLOWED_TOOLS)}


@app.post("/run", response_model=RunResponse)
def run(req: RunRequest, authorization: str | None = Header(default=None)) -> RunResponse:
    _require_token(authorization)

    request_id = req.request_id or str(uuid.uuid4())
    if req.tool not in ALLOWED_TOOLS:
        raise HTTPException(status_code=403, detail="tool not allowed")

    validate_agent_scope(req.agent, req.scope.model_dump())
    policy = _effective_policy(req)

    host_ws = _host_workspace_path(req.agent, req.scope)

    # Spawn a short-lived job container with a bind mount ONLY for this workspace.
    job_image = get_required_env("JOB_IMAGE")
    sandbox_net = get_required_env("SANDBOX_NET_NAME")

    volumes = {
        host_ws: {
            "bind": "/workspace",
            "mode": "rw" if policy.fs_mode == "rw" else "ro",
        }
    }

    # Network: none by default; allow sandbox_net if allowlist is used (curl will still be host-checked in job).
    network_mode = "none"
    network = None
    if policy.net_mode == "allowlist":
        network_mode = None
        network = sandbox_net

    job_req = {
        "tool": req.tool,
        "args": req.args,
        "policy": {
            "fs_mode": policy.fs_mode,
            "net_mode": policy.net_mode,
            "net_allow": sorted(policy.net_allow),
            "timeout_s": policy.timeout_s,
        },
    }

    client = docker.from_env()
    try:
        container = client.containers.run(
            image=job_image,
            command=["python", "-m", "app.job", f"--req_b64={b64json_dumps(job_req)}"],
            remove=False,
            detach=True,
            read_only=True,
            security_opt=["no-new-privileges:true"],
            cap_drop=["ALL"],
            pids_limit=128,
            mem_limit="512m",
            nano_cpus=int(1e9),  # 1 CPU
            tmpfs={"/tmp": ""},
            volumes=volumes,
            network_mode=network_mode,
            network=network,
            environment={"PYTHONUNBUFFERED": "1"},
        )
        res = container.wait(timeout=policy.timeout_s + 5)
        logs = (container.logs(stdout=True, stderr=True) or b"")[:200_000]
        code = int(res.get("StatusCode", 1))
    except Exception:
        raise HTTPException(status_code=500, detail="job_spawn_failed")
    finally:
        try:
            if "container" in locals():
                container.remove(force=True)
        except Exception:
            pass

    # Job writes a single JSON object to stdout; cap and parse defensively.
    try:
        obj = json.loads(logs.decode("utf-8", errors="replace").strip() or "{}")
    except Exception:
        obj = {"ok": False, "error": "invalid_job_output"}

    ok = bool(obj.get("ok", False)) and code == 0
    stdout = str(obj.get("stdout", ""))[:80_000]
    stderr = str(obj.get("stderr", ""))[:80_000]
    artifacts = obj.get("artifacts") or []
    resp_artifacts: list[Artifact] = []
    for a in artifacts:
        if isinstance(a, dict) and isinstance(a.get("path"), str) and a.get("type") in ("text", "file"):
            resp_artifacts.append(Artifact(path=a["path"], type=a["type"]))

    return RunResponse(
        request_id=request_id,
        ok=ok,
        stdout=stdout,
        stderr=stderr,
        artifacts=resp_artifacts,
        error=None if ok else str(obj.get("error") or "failed")[:500],
    )
