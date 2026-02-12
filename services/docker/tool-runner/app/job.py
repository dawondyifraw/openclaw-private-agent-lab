from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Literal

from .common import (
    ALLOWED_BINARIES,
    ALLOWED_INTERNAL_HOSTS,
    ALLOWED_TOOLS,
    b64json_loads,
    enforce_curl_policy,
    safe_relpath,
)


def _is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except Exception:
        return False


def _safe_join(root: Path, rel_path: str) -> Path:
    rel_path = safe_relpath(rel_path)
    target = (root / rel_path).resolve()
    if not _is_relative_to(target, root):
        raise PermissionError("path escape blocked")
    return target


def _json_out(obj: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=True))
    sys.stdout.flush()


def main() -> int:
    # The spawner passes the request via env var to avoid stdin plumbing.
    b64 = None
    for arg in sys.argv[1:]:
        if arg.startswith("--req_b64="):
            b64 = arg.split("=", 1)[1]
            break
    if not b64:
        _json_out({"ok": False, "error": "missing_request"})
        return 2

    req = b64json_loads(b64)
    tool = req.get("tool")
    if tool not in ALLOWED_TOOLS:
        _json_out({"ok": False, "error": "tool_not_allowed"})
        return 3

    root = Path("/workspace").resolve()
    args = req.get("args") or {}
    policy = req.get("policy") or {}

    fs_mode: Literal["ro", "rw"] = policy.get("fs_mode", "ro")
    net_mode: Literal["none", "allowlist"] = policy.get("net_mode", "none")
    net_allow = set(policy.get("net_allow") or [])
    if net_allow - ALLOWED_INTERNAL_HOSTS:
        _json_out({"ok": False, "error": "net_allow_forbidden"})
        return 4

    timeout_s = int(policy.get("timeout_s", 10))
    timeout_s = max(1, min(timeout_s, 60))

    try:
        if tool == "file_read":
            rel_path = str(args.get("path", ""))
            max_bytes = int(args.get("max_bytes", 200_000))
            max_bytes = max(1, min(max_bytes, 2_000_000))

            target = _safe_join(root, rel_path)
            data = target.read_bytes()[:max_bytes]
            try:
                text = data.decode("utf-8")
            except Exception:
                text = data.decode("utf-8", errors="replace")
            _json_out({"ok": True, "stdout": text, "stderr": ""})
            return 0

        if tool == "file_write":
            if fs_mode != "rw":
                _json_out({"ok": False, "error": "write_denied"})
                return 5
            rel_path = str(args.get("path", ""))
            content = args.get("content", "")
            if not isinstance(content, str):
                _json_out({"ok": False, "error": "invalid_content"})
                return 6
            target = _safe_join(root, rel_path)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
            _json_out({"ok": True, "stdout": "OK", "stderr": "", "artifacts": [{"path": rel_path, "type": "file"}]})
            return 0

        if tool == "shell_exec":
            cmd = args.get("cmd")
            if not isinstance(cmd, list) or not cmd or not all(isinstance(x, str) for x in cmd):
                _json_out({"ok": False, "error": "invalid_cmd"})
                return 7

            if cmd[0] in ("sh", "bash", "zsh", "fish"):
                _json_out({"ok": False, "error": "shell_denied"})
                return 8

            if cmd[0] not in ALLOWED_BINARIES:
                _json_out({"ok": False, "error": f"binary_denied:{cmd[0]}"})
                return 9

            # Network enforcement. The container network layer should also block external egress.
            if cmd[0] == "curl":
                try:
                    enforce_curl_policy(cmd, net_mode, net_allow)
                except Exception as e:
                    _json_out({"ok": False, "error": f"net_denied:{str(e)}"})
                    return 10
            else:
                if net_mode != "none":
                    _json_out({"ok": False, "error": "net_policy_denied"})
                    return 11

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
                _json_out({"ok": False, "error": "timeout"})
                return 12
            except Exception:
                _json_out({"ok": False, "error": "execution_error"})
                return 13

            stdout = (p.stdout or "")[:80_000]
            stderr = (p.stderr or "")[:80_000]
            if p.returncode == 0:
                _json_out({"ok": True, "stdout": stdout, "stderr": stderr})
                return 0
            _json_out({"ok": False, "stdout": stdout, "stderr": stderr, "error": f"exit_{p.returncode}"})
            return 0

        _json_out({"ok": False, "error": "unreachable"})
        return 99
    except PermissionError:
        _json_out({"ok": False, "error": "denied"})
        return 14
    except FileNotFoundError:
        _json_out({"ok": False, "error": "not_found"})
        return 15
    except Exception:
        # Avoid tracebacks in output.
        _json_out({"ok": False, "error": "job_error"})
        return 16


if __name__ == "__main__":
    raise SystemExit(main())

