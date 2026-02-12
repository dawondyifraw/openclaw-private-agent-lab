from __future__ import annotations

import base64
import json
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal
from urllib.parse import urlparse


ALLOWED_INTERNAL_HOSTS = {"ollama", "rag-service"}

ALLOWED_TOOLS = {"file_read", "file_write", "shell_exec"}

ALLOWED_BINARIES = {
    # Keep this tight. Expand only with explicit review.
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


def workspace_key(scope: dict[str, Any]) -> str:
    if scope.get("type") == "telegram":
        chat_id = scope.get("chat_id")
        if not chat_id or not isinstance(chat_id, str):
            raise ValueError("scope.chat_id is required for telegram scope")
        return f"group_{chat_id}"
    raise ValueError(f"unsupported scope.type: {scope.get('type')!r}")


def validate_agent_scope(agent: str, scope: dict[str, Any]) -> None:
    if not AGENT_RE.match(agent or ""):
        raise ValueError("invalid agent")
    if not SCOPE_TYPE_RE.match(str(scope.get("type", ""))):
        raise ValueError("invalid scope.type")


def safe_relpath(rel_path: str) -> str:
    if not isinstance(rel_path, str) or not rel_path:
        raise ValueError("path required")
    if "\x00" in rel_path:
        raise ValueError("invalid path")
    if rel_path.startswith("/") or rel_path.startswith("\\"):
        raise PermissionError("absolute paths are not allowed")
    # Reject obvious traversal; job container still enforces containment.
    if rel_path.split("/")[0] in (".", "..") or "/../" in rel_path or rel_path.endswith("/.."):
        raise PermissionError("path traversal blocked")
    return rel_path


def enforce_curl_policy(cmd: list[str], net_mode: Literal["none", "allowlist"], net_allow: set[str]) -> None:
    if len(cmd) < 2:
        raise ValueError("curl requires a URL")

    allowed_flags = {"-f", "-s", "-S", "-fsS", "-m"}
    url = None
    i = 1
    while i < len(cmd):
        tok = cmd[i]
        if tok.startswith("-"):
            if tok not in allowed_flags:
                raise PermissionError(f"curl flag not allowed: {tok}")
            if tok == "-m":
                if i + 1 >= len(cmd):
                    raise ValueError("curl -m requires seconds")
                i += 2
                continue
            i += 1
            continue
        url = tok
        break

    if not url:
        raise ValueError("curl URL missing")

    if net_mode != "allowlist":
        raise PermissionError("network denied by policy")

    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise PermissionError("only http/https URLs are allowed")
    host = parsed.hostname
    if not host:
        raise ValueError("URL hostname missing")
    if host not in net_allow:
        raise PermissionError(f"host not allowed by policy: {host}")


def b64json_dumps(obj: Any) -> str:
    raw = json.dumps(obj, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    return base64.b64encode(raw).decode("ascii")


def b64json_loads(s: str) -> Any:
    raw = base64.b64decode(s.encode("ascii"))
    return json.loads(raw.decode("utf-8"))


@dataclass(frozen=True)
class EffectivePolicy:
    fs_mode: Literal["ro", "rw"]
    net_mode: Literal["none", "allowlist"]
    net_allow: set[str]
    timeout_s: int


def get_required_env(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        raise RuntimeError(f"missing required env: {name}")
    return v

