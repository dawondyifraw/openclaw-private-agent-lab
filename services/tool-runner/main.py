from __future__ import annotations

import os
import re
import subprocess
import uuid
from pathlib import Path
from typing import Any, Literal
from urllib.parse import urlparse

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

APP_VERSION = "0.1.0"

WORKSPACES_ROOT = Path(os.environ.get("WORKSPACES_ROOT", "/workspaces"))

ALLOWED_INTERNAL_HOSTS = {"ollama", "rag-service"}

# Keep this tight. Add tools only with explicit security review.
ALLOWED_TOOLS = {
    "file_read",
    "file_write",
    "shell_exec",
}

# Allowed binaries for shell_exec.
# We intentionally do NOT allow general-purpose file utilities (cat/find/tar/cp) to avoid cross-scope access.
ALLOWED_BINARIES = {
    "curl",
    "python3",
    "python",
    "pytest",
}

AGENT_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")
SCOPE_TYPE_RE = re.compile(r"^[a-z0-9_-]{1,32}$")


def _is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except Exception:
        return False


def _workspace_key(scope: "Scope") -> str:
    if scope.type == "telegram":
        if scope.chat_id is None or not scope.chat_id:
            raise HTTPException(status_code=400, detail="scope.chat_id is required for telegram scope")
        # Keep the directory key stable and explicit.
        return f"group_{scope.chat_id}"
    raise HTTPException(status_code=400, detail=f"unsupported scope.type: {scope.type}")


def _agent_workspace_root(agent: str, scope: "Scope") -> Path:
    if not AGENT_RE.match(agent):
        raise HTTPException(status_code=400, detail="invalid agent")
    if not SCOPE_TYPE_RE.match(scope.type):
        raise HTTPException(status_code=400, detail="invalid scope.type")

    key = _workspace_key(scope)
    # The key may contain '-' from Telegram IDs; that's fine.
    root = (WORKSPACES_ROOT / agent / key).resolve()

    # Ensure the computed root stays under WORKSPACES_ROOT.
    ws_root = WORKSPACES_ROOT.resolve()
    if not _is_relative_to(root, ws_root):
        raise HTTPException(status_code=403, detail="workspace root escape blocked")

    if not root.exists() or not root.is_dir():
        raise HTTPException(status_code=404, detail=f"workspace root not found: {agent}/{key}")

    return root


def _safe_join(root: Path, rel_path: str) -> Path:
    if "\x00" in rel_path:
        raise HTTPException(status_code=400, detail="invalid path")

    # Disallow absolute paths.
    if rel_path.startswith("/") or rel_path.startswith("\\"):
        raise HTTPException(status_code=403, detail="absolute paths are not allowed")

    # Normalize and resolve to handle symlinks.
    target = (root / rel_path).resolve()
    if not _is_relative_to(target, root):
        raise HTTPException(status_code=403, detail="path escape blocked")

    return target


def _classify_net_policy(policy: "Policy") -> tuple[Literal["none", "allowlist"], set[str]]:
    mode = policy.net.mode
    allow = set(policy.net.allow or [])

    if mode == "none":
        return mode, set()

    # allowlist mode
    bad = [x for x in allow if x not in ALLOWED_INTERNAL_HOSTS]
    if bad:
        raise HTTPException(status_code=403, detail=f"net allowlist contains forbidden hosts: {bad}")

    return mode, allow


def _enforce_curl_policy(cmd: list[str], net_mode: str, net_allow: set[str]) -> None:
    # Expected: curl <url> with optional -fsS/-m.
    if len(cmd) < 2:
        raise HTTPException(status_code=400, detail="curl requires a URL")

    allowed_flags = {"-f", "-s", "-S", "-fsS", "-m"}
    url = None
    i = 1
    while i < len(cmd):
        tok = cmd[i]
        if tok.startswith("-"):
            if tok not in allowed_flags:
                raise HTTPException(status_code=403, detail=f"curl flag not allowed: {tok}")
            if tok == "-m":
                # next token should be seconds
                if i + 1 >= len(cmd):
                    raise HTTPException(status_code=400, detail="curl -m requires seconds")
                i += 2
                continue
            i += 1
            continue

        url = tok
        break

    if not url:
        raise HTTPException(status_code=400, detail="curl URL missing")

    if net_mode != "allowlist":
        raise HTTPException(status_code=403, detail="network denied by policy")

    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise HTTPException(status_code=403, detail="only http/https URLs are allowed")

    host = parsed.hostname
    if not host:
        raise HTTPException(status_code=400, detail="URL hostname missing")

    # External internet is blocked at the Docker network layer; we still enforce a hostname allowlist.
    if host not in net_allow:
        raise HTTPException(status_code=403, detail=f"host not allowed by policy: {host}")


class Scope(BaseModel):
    type: Literal["telegram"]
    chat_id: str | None = None
    user_id: str | None = None


class FsPolicy(BaseModel):
    mode: Literal["ro", "rw"] = "ro"
    root: str | None = None  # ignored server-side


class NetPolicy(BaseModel):
    mode: Literal["none", "allowlist"] = "none"
    allow: list[str] | None = None


class Policy(BaseModel):
    fs: FsPolicy = Field(default_factory=FsPolicy)
    net: NetPolicy = Field(default_factory=NetPolicy)
    timeout_s: int = 10


class RunRequest(BaseModel):
    request_id: str | None = None
    agent: str
    scope: Scope
    tool: str
    args: dict[str, Any] = Field(default_factory=dict)
    policy: Policy = Field(default_factory=Policy)


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


app = FastAPI(title="OpenClaw Tool Runner", version=APP_VERSION)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "version": APP_VERSION,
        "workspaces_root": str(WORKSPACES_ROOT),
        "tools": sorted(ALLOWED_TOOLS),
    }


@app.post("/run", response_model=RunResponse)
def run(req: RunRequest) -> RunResponse:
    request_id = req.request_id or str(uuid.uuid4())

    if req.tool not in ALLOWED_TOOLS:
        raise HTTPException(status_code=403, detail="tool not allowed")

    # Clamp timeout.
    timeout_s = max(1, min(int(req.policy.timeout_s), 60))

    # Resolve workspace root (server-controlled).
    root = _agent_workspace_root(req.agent, req.scope)

    # Compute effective policies (server-controlled).
    fs_mode = req.policy.fs.mode
    net_mode, net_allow = _classify_net_policy(req.policy)

    if req.tool == "file_read":
        rel_path = str(req.args.get("path", ""))
        max_bytes = int(req.args.get("max_bytes", 200_000))
        max_bytes = max(1, min(max_bytes, 2_000_000))

        target = _safe_join(root, rel_path)
        if not target.exists() or not target.is_file():
            raise HTTPException(status_code=404, detail="file not found")

        data = target.read_bytes()[:max_bytes]
        # Return as text with best-effort decoding.
        try:
            text = data.decode("utf-8")
        except Exception:
            text = data.decode("utf-8", errors="replace")

        return RunResponse(request_id=request_id, ok=True, stdout=text)

    if req.tool == "file_write":
        if fs_mode != "rw":
            raise HTTPException(status_code=403, detail="write denied by policy")

        rel_path = str(req.args.get("path", ""))
        content = req.args.get("content", "")
        if not isinstance(content, str):
            raise HTTPException(status_code=400, detail="content must be a string")

        target = _safe_join(root, rel_path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

        return RunResponse(
            request_id=request_id,
            ok=True,
            stdout="OK",
            artifacts=[Artifact(path=rel_path, type="file")],
        )

    if req.tool == "shell_exec":
        cmd = req.args.get("cmd")
        if not isinstance(cmd, list) or not all(isinstance(x, str) for x in cmd):
            raise HTTPException(status_code=400, detail="args.cmd must be a list of strings")
        if not cmd:
            raise HTTPException(status_code=400, detail="empty cmd")

        # Hard rule: never invoke a shell.
        if cmd[0] in ("sh", "bash", "zsh", "fish"):
            raise HTTPException(status_code=403, detail="shell is not allowed")

        if cmd[0] not in ALLOWED_BINARIES:
            raise HTTPException(status_code=403, detail=f"binary not allowed: {cmd[0]}")

        # Network enforcement for curl.
        if cmd[0] == "curl":
            _enforce_curl_policy(cmd, net_mode, net_allow)
        else:
            # Default: no network for other commands.
            if net_mode != "none":
                raise HTTPException(status_code=403, detail="net allowlist applies only to curl in this build")

        try:
            p = subprocess.run(
                cmd,
                cwd=str(root),
                capture_output=True,
                text=True,
                timeout=timeout_s,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return RunResponse(request_id=request_id, ok=False, error="timeout")
        except Exception:
            # Do not leak stack traces.
            return RunResponse(request_id=request_id, ok=False, error="execution_error")

        # Cap output sizes.
        stdout = (p.stdout or "")[:80_000]
        stderr = (p.stderr or "")[:80_000]

        if p.returncode == 0:
            return RunResponse(request_id=request_id, ok=True, stdout=stdout, stderr=stderr)

        return RunResponse(
            request_id=request_id,
            ok=False,
            stdout=stdout,
            stderr=stderr,
            error=f"exit_{p.returncode}",
        )

    raise HTTPException(status_code=500, detail="unreachable")
