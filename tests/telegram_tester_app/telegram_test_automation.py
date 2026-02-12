#!/usr/bin/env python3
"""Telegram group test automation runner.

This script is intentionally group-focused. It sends test commands to configured
Telegram groups and validates bot responses.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import schedule
import yaml
from dotenv import load_dotenv
from jinja2 import Template
from telethon import TelegramClient
from telethon.errors import (
    FloodWaitError,
    PhoneCodeExpiredError,
    PhoneCodeInvalidError,
    PhoneNumberBannedError,
    PhoneNumberFloodError,
    PhonePasswordFloodError,
    SessionPasswordNeededError,
)

logger = logging.getLogger("telegram-test-automation")


def _setup_logging() -> None:
    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def _read_float_env(name: str) -> float | None:
    raw = (os.getenv(name) or "").strip()
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError as exc:
        raise ValueError(f"{name} must be numeric, got {raw!r}") from exc


def _matches_forbidden_pattern(text: str, pattern: str) -> bool:
    """Match forbidden pattern safely.

    - `re:<expr>` means regex match (case-insensitive)
    - otherwise, do case-insensitive literal containment
    """
    if pattern.startswith("re:"):
        expr = pattern[3:]
        return bool(re.search(expr, text, flags=re.IGNORECASE))
    return pattern.lower() in text.lower()


@dataclass
class TestResult:
    group_key: str
    suite_name: str
    command: str
    description: str
    validator: str
    passed: bool
    response_text: str
    reason: str
    started_at: str
    duration_seconds: float


@dataclass
class RunSummary:
    started_at: str
    finished_at: str
    total: int
    passed: int
    failed: int
    skipped: int
    groups: list[str] = field(default_factory=list)


class TelegramBotTester:
    def __init__(self, config_path: str = "config.yaml", tests_path: str = "group_tests.yaml"):
        load_dotenv(override=False)

        self.base_dir = Path(__file__).resolve().parent
        self.config_path = self.base_dir / config_path
        self.tests_path = self.base_dir / tests_path
        self.client: TelegramClient | None = None
        self.bot_entity = None
        self.config: dict[str, Any] = {}
        self.tests: dict[str, Any] = {}
        self.results: list[TestResult] = []

        self.is_docker = Path("/.dockerenv").exists()
        self.flood_wait_until: datetime | None = None
        self.consecutive_failures = 0

        self.session_dir = self.base_dir / "sessions"
        self.session_dir.mkdir(parents=True, exist_ok=True)

        self.report_dir = self.base_dir / "test_reports"
        self.report_dir.mkdir(parents=True, exist_ok=True)

        self._load_files()
        session_name = self._get_config_value("telegram.session_name") or "bot_tester"
        self.session_path = str(self.session_dir / session_name)

    def _load_files(self) -> None:
        self.config = self._load_yaml(self.config_path)
        self.tests = self._load_tests_with_fallback()

    def _load_yaml(self, path: Path) -> dict[str, Any]:
        if not path.exists():
            raise FileNotFoundError(f"Missing YAML file: {path}")

        raw = path.read_text(encoding="utf-8")

        # Expand ${ENV_VAR} placeholders for config values.
        def repl(match: re.Match[str]) -> str:
            key = match.group(1)
            return os.getenv(key, "")

        expanded = re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", repl, raw)
        data = yaml.safe_load(expanded) or {}
        if not isinstance(data, dict):
            raise ValueError(f"Expected top-level object in {path}")
        return data

    def _load_tests_with_fallback(self) -> dict[str, Any]:
        candidate_paths = [self.tests_path, self.base_dir / "group_test.yaml"]

        for candidate in candidate_paths:
            if not candidate.exists():
                continue
            data = self._load_yaml(candidate)
            suites = data.get("test_suites")
            if isinstance(suites, dict) and suites:
                if candidate != self.tests_path:
                    logger.warning(
                        "Using fallback tests file %s because %s has no usable suites",
                        candidate.name,
                        self.tests_path.name,
                    )
                return data

        raise ValueError(
            "No valid test suites found. Expected non-empty `test_suites` in group_tests.yaml "
            "or group_test.yaml"
        )

    def _get_config_value(self, dotted_path: str, default: Any = None) -> Any:
        node: Any = self.config
        for part in dotted_path.split("."):
            if not isinstance(node, dict) or part not in node:
                return default
            node = node[part]
        return node

    async def start(self) -> None:
        """Start the Telegram client with session persistence and flood protection."""
        if self.flood_wait_until and datetime.now() < self.flood_wait_until:
            wait_seconds = (self.flood_wait_until - datetime.now()).total_seconds()
            raise RuntimeError(f"Flood wait active for {int(wait_seconds)} seconds")

        api_id = self._get_config_value("telegram.api_id")
        api_hash = self._get_config_value("telegram.api_hash")

        if not api_id or not api_hash:
            raise ValueError("telegram.api_id and telegram.api_hash are required")

        try:
            api_id = int(api_id)
        except ValueError as exc:
            raise ValueError(f"API_ID must be an integer, got {api_id!r}") from exc

        self.client = TelegramClient(
            self.session_path,
            api_id,
            api_hash,
            timeout=30,
            connection_retries=3,
            retry_delay=5,
        )

        try:
            await self.client.connect()
            if not await self.client.is_user_authorized():
                await self._interactive_login()
            else:
                logger.info("Using existing Telegram session")

            await self._load_bot_entity()
            me = await self.client.get_me()
            self._validate_tester_identity(me)
            logger.info("Client authorized as %s (id=%s)", me.username or me.first_name or me.phone, me.id)
            self.consecutive_failures = 0
        except Exception:
            self.consecutive_failures += 1
            if self.client:
                await self.client.disconnect()
            raise

    async def _interactive_login(self) -> None:
        if not self.client:
            raise RuntimeError("Client is not initialized")

        phone = (os.getenv("TG_PHONE") or "").strip()
        if not phone:
            if sys.stdin.isatty():
                phone = input("Phone number (+countrycode): ").strip()
            else:
                raise ValueError("TG_PHONE is required for first-time login")

        try:
            sent = await self.client.send_code_request(phone)
            logger.info("Verification code requested for %s", phone)
        except PhoneNumberFloodError:
            self.flood_wait_until = datetime.now() + timedelta(hours=24)
            raise RuntimeError("Phone number is flooded. Wait ~24h before retrying")
        except PhoneNumberBannedError:
            raise RuntimeError("This phone number is banned from Telegram API")
        except FloodWaitError as exc:
            self.flood_wait_until = datetime.now() + timedelta(seconds=exc.seconds)
            raise RuntimeError(f"Flood wait required: {exc.seconds}s") from exc

        code = (os.getenv("TG_CODE") or "").strip()
        if not code:
            if sys.stdin.isatty():
                code = input("Enter the code you received: ").strip()
            else:
                raise ValueError("TG_CODE is required for first-time non-interactive login")

        code = code.replace(" ", "").replace("-", "")

        try:
            await self.client.sign_in(phone=phone, code=code, phone_code_hash=sent.phone_code_hash)
            logger.info("Code verification succeeded")
        except SessionPasswordNeededError:
            await self._complete_2fa()
        except PhoneCodeInvalidError:
            raise RuntimeError("Invalid verification code")
        except PhoneCodeExpiredError:
            raise RuntimeError("Verification code expired. Request a new one")

    async def _complete_2fa(self) -> None:
        if not self.client:
            raise RuntimeError("Client is not initialized")

        password = (os.getenv("TG_PASSWORD") or os.getenv("TG_2FA_PASSWORD") or "").strip()
        if not password:
            if sys.stdin.isatty():
                password = input("Enter your Telegram 2FA password: ").strip()
            else:
                raise ValueError("2FA is enabled. Set TG_PASSWORD (or TG_2FA_PASSWORD)")

        try:
            await self.client.sign_in(password=password)
            logger.info("2FA authentication succeeded")
        except PhonePasswordFloodError:
            self.flood_wait_until = datetime.now() + timedelta(hours=24)
            raise RuntimeError("Too many 2FA attempts. Wait ~24h before retrying")
        except FloodWaitError as exc:
            self.flood_wait_until = datetime.now() + timedelta(seconds=exc.seconds)
            raise RuntimeError(f"Flood wait required: {exc.seconds}s") from exc
        except Exception as exc:
            raise RuntimeError("2FA authentication failed. Check TG_PASSWORD") from exc

    async def _load_bot_entity(self) -> None:
        if not self.client:
            raise RuntimeError("Client is not initialized")

        bot_id = self._get_config_value("telegram.bot_id")
        bot_username = self._get_config_value("telegram.bot_username")
        if not bot_id and not bot_username:
            logger.warning("telegram.bot_id/bot_username not set; response attribution will use fallback logic")
            return

        try:
            if bot_id:
                self.bot_entity = await self.client.get_entity(int(bot_id))
                logger.info("Bot resolved by id: %s", self.bot_entity.id)
            else:
                self.bot_entity = await self.client.get_entity(bot_username)
                logger.info("Bot resolved: @%s (id=%s)", self.bot_entity.username, self.bot_entity.id)
        except FloodWaitError as exc:
            logger.warning("Flood wait while resolving bot. Sleeping %ss", exc.seconds)
            await asyncio.sleep(exc.seconds)
            if bot_id:
                self.bot_entity = await self.client.get_entity(int(bot_id))
            else:
                self.bot_entity = await self.client.get_entity(bot_username)
        except Exception as exc:
            logger.warning("Could not resolve bot entity (%s). Continuing with reply-based matching.", exc)

    def _validate_tester_identity(self, me: Any) -> None:
        tester_id_raw = (os.getenv("TG_TESTER_ID") or "").strip()
        if not tester_id_raw:
            return
        try:
            expected_id = int(tester_id_raw)
        except ValueError as exc:
            raise ValueError(f"TG_TESTER_ID must be an integer, got {tester_id_raw!r}") from exc

        if me.id != expected_id:
            raise RuntimeError(
                f"Logged-in account id ({me.id}) does not match TG_TESTER_ID ({expected_id}). "
                "Update TG_TESTER_ID or switch account/session."
            )

    async def stop(self) -> None:
        if self.client:
            await self.client.disconnect()
            self.client = None

    def _resolve_groups(self, selected_groups: list[str] | None) -> list[str]:
        groups_cfg = self.config.get("groups", {})
        if not isinstance(groups_cfg, dict):
            raise ValueError("config.yaml: `groups` must be an object")

        if selected_groups:
            requested = [g.strip() for g in selected_groups if g.strip()]
        else:
            env_groups = (os.getenv("TEST_GROUPS") or "").strip()
            requested = [g.strip() for g in env_groups.split(",") if g.strip()] if env_groups else list(groups_cfg.keys())

        missing = [g for g in requested if g not in groups_cfg]
        if missing:
            raise ValueError(f"Unknown groups requested: {missing}")

        return requested

    def preflight(
        self,
        selected_groups: list[str] | None = None,
        mode: str = "all",
        max_tests: int | None = None,
    ) -> dict[str, Any]:
        """Validate local setup without connecting to Telegram."""
        groups = self._resolve_groups(selected_groups)
        suite_map = self.tests.get("test_suites", {})

        api_id = self._get_config_value("telegram.api_id")
        api_hash = self._get_config_value("telegram.api_hash")
        if not api_id or not api_hash:
            raise ValueError("telegram.api_id and telegram.api_hash are required")
        try:
            int(api_id)
        except ValueError as exc:
            raise ValueError(f"API_ID must be an integer, got {api_id!r}") from exc

        tester_id_raw = (os.getenv("TG_TESTER_ID") or "").strip()
        if tester_id_raw:
            try:
                int(tester_id_raw)
            except ValueError as exc:
                raise ValueError(f"TG_TESTER_ID must be an integer, got {tester_id_raw!r}") from exc

        suites_to_use = ["normal_tests", "worst_case_tests"] if mode == "all" else [f"{mode}_tests"]

        per_group: dict[str, Any] = {}
        total_cases = 0
        skipped_groups = []
        for group_key in groups:
            group_cfg = self.config["groups"].get(group_key, {})
            group_id = group_cfg.get("id")
            if group_id is None:
                skipped_groups.append(group_key)
                per_group[group_key] = {"enabled": False, "reason": "group id is null", "tests": 0}
                continue

            tests_for_group = suite_map.get(group_key, {})
            count = 0
            for suite_name in suites_to_use:
                for item in tests_for_group.get(suite_name, []) or []:
                    if str(item.get("command", "")).strip():
                        count += 1
            per_group[group_key] = {"enabled": True, "reason": "ok", "tests": count}
            total_cases += count

        effective_total = min(total_cases, max_tests) if max_tests is not None else total_cases

        return {
            "mode": mode,
            "groups_requested": groups,
            "groups_skipped": skipped_groups,
            "total_cases": total_cases,
            "effective_total_cases": effective_total,
            "per_group": per_group,
            "tests_file": str(self.tests_path),
        }

    async def run(
        self,
        selected_groups: list[str] | None = None,
        mode: str = "all",
        max_tests: int | None = None,
    ) -> RunSummary:
        started = datetime.utcnow()
        groups = self._resolve_groups(selected_groups)
        suite_map = self.tests.get("test_suites", {})
        forbidden_patterns = self.config.get("forbidden_patterns", [])
        timeouts = self.config.get("timeouts", {})
        response_wait = int(timeouts.get("response_wait", 30))
        between_tests = float(timeouts.get("between_tests", 2))
        env_between = _read_float_env("TEST_BETWEEN_DELAY")
        if env_between is not None:
            between_tests = env_between

        skipped = 0
        executed = 0
        for group_key in groups:
            if max_tests is not None and executed >= max_tests:
                logger.warning("Max test limit reached (%s). Stopping early.", max_tests)
                break

            group_cfg = self.config["groups"].get(group_key, {})
            group_id = group_cfg.get("id")
            if group_id is None:
                logger.warning("Skipping group %s: id is null", group_key)
                skipped += 1
                continue

            tests_for_group = suite_map.get(group_key)
            if not tests_for_group:
                logger.warning("Skipping group %s: no tests defined", group_key)
                skipped += 1
                continue

            group_executed = await self._run_group_tests(
                group_key=group_key,
                group_id=group_id,
                tests_for_group=tests_for_group,
                mode=mode,
                response_wait=response_wait,
                between_tests=between_tests,
                forbidden_patterns=forbidden_patterns,
                remaining_tests=(None if max_tests is None else max_tests - executed),
            )
            executed += group_executed

        passed = sum(1 for r in self.results if r.passed)
        failed = sum(1 for r in self.results if not r.passed)
        finished = datetime.utcnow()

        summary = RunSummary(
            started_at=started.isoformat() + "Z",
            finished_at=finished.isoformat() + "Z",
            total=len(self.results),
            passed=passed,
            failed=failed,
            skipped=skipped,
            groups=groups,
        )

        self._write_reports(summary)
        return summary

    async def _run_group_tests(
        self,
        group_key: str,
        group_id: int,
        tests_for_group: dict[str, Any],
        mode: str,
        response_wait: int,
        between_tests: float,
        forbidden_patterns: list[str],
        remaining_tests: int | None,
    ) -> int:
        if not self.client:
            raise RuntimeError("Client is not initialized")

        try:
            entity = await self.client.get_entity(group_id)
        except Exception as exc:
            logger.error("Group %s not accessible (id=%s): %s", group_key, group_id, exc)
            return 0

        logger.info("Running tests for %s (%s)", group_key, getattr(entity, "title", group_id))

        suite_names = ["normal_tests", "worst_case_tests"] if mode == "all" else [f"{mode}_tests"]
        executed = 0

        for suite_name in suite_names:
            items = tests_for_group.get(suite_name, []) or []
            for item in items:
                if remaining_tests is not None and executed >= remaining_tests:
                    return executed

                started = datetime.utcnow()
                command = str(item.get("command", "")).strip()
                validator = str(item.get("validator", "min_length_1")).strip()
                description = str(item.get("description", "")).strip()

                if not command:
                    continue

                response = await self._send_and_collect(entity, command, response_wait)
                passed, reason = self._validate_response(
                    command=command,
                    response=response,
                    validator=validator,
                    forbidden_patterns=forbidden_patterns,
                )

                duration = (datetime.utcnow() - started).total_seconds()
                self.results.append(
                    TestResult(
                        group_key=group_key,
                        suite_name=suite_name,
                        command=command,
                        description=description,
                        validator=validator,
                        passed=passed,
                        response_text=response,
                        reason=reason,
                        started_at=started.isoformat() + "Z",
                        duration_seconds=duration,
                    )
                )

                state = "PASS" if passed else "FAIL"
                logger.info("[%s] %s | %s", state, group_key, command)
                if not passed:
                    logger.info("Reason: %s", reason)

                executed += 1
                await asyncio.sleep(between_tests)

        return executed

    async def _send_and_collect(self, entity: Any, command: str, response_wait: int) -> str:
        if not self.client:
            raise RuntimeError("Client is not initialized")

        sent = await self.client.send_message(entity, command)
        start_time = datetime.utcnow()
        deadline = start_time + timedelta(seconds=response_wait)

        last_seen = ""
        while datetime.utcnow() < deadline:
            messages = await self.client.get_messages(entity, limit=30)
            for msg in messages:
                text = (msg.message or "").strip()
                if not text:
                    continue
                if msg.id == sent.id:
                    continue
                if msg.date.replace(tzinfo=None) < start_time - timedelta(seconds=2):
                    continue

                # Prefer response from bot account when known.
                if self.bot_entity is not None and getattr(msg, "sender_id", None) == self.bot_entity.id:
                    return text

                # Fallback when bot identity cannot be verified: direct reply to sent message.
                reply_to = getattr(msg, "reply_to", None)
                if reply_to and getattr(reply_to, "reply_to_msg_id", None) == sent.id:
                    return text

                # Last fallback: latest non-outgoing message after command.
                if not msg.out:
                    last_seen = text

            await asyncio.sleep(2)

        return last_seen

    def _validate_response(
        self,
        command: str,
        response: str,
        validator: str,
        forbidden_patterns: list[str],
    ) -> tuple[bool, str]:
        text = (response or "").strip()
        low = text.lower()

        if validator == "min_length_1":
            ok = len(text) >= 1
            return ok, "empty response" if not ok else "ok"
        if validator == "min_length_5":
            ok = len(text) >= 5
            return ok, "response shorter than 5 chars" if not ok else "ok"
        if validator == "min_length_10":
            ok = len(text) >= 10
            return ok, "response shorter than 10 chars" if not ok else "ok"

        if validator == "unknown_command":
            ok = any(k in low for k in ["unknown", "not recognized", "help", "invalid"])
            return ok, "did not look like unknown-command response" if not ok else "ok"
        if validator == "not_unknown":
            bad = any(k in low for k in ["unknown command", "not recognized", "invalid command"])
            return (not bad, "looks like unknown-command response" if bad else "ok")

        if validator == "same_as_dash":
            ok = "dash" in low or "dashboard" in low
            return ok, "expected dashboard-like response" if not ok else "ok"
        if validator == "contains_added":
            ok = any(k in low for k in ["added", "created", "saved"])
            return ok, "expected add confirmation" if not ok else "ok"
        if validator == "contains_task":
            ok = "task" in low
            return ok, "expected task-related response" if not ok else "ok"
        if validator == "contains_reminder":
            ok = "remind" in low or "reminder" in low
            return ok, "expected reminder-related response" if not ok else "ok"
        if validator == "contains_import_csv":
            ok = "import csv" in low or "csv" in low
            return ok, "expected CSV-related response" if not ok else "ok"

        if validator == "contains_current_month":
            month = datetime.utcnow().strftime("%B").lower()
            ok = month in low
            return ok, f"expected current month name ({month})" if not ok else "ok"

        if validator == "contains_amharic":
            ok = bool(re.search(r"[\u1200-\u137F]", text))
            return ok, "expected Amharic characters" if not ok else "ok"
        if validator == "not_chinese":
            ok = not bool(re.search(r"[\u4E00-\u9FFF]", text))
            return ok, "contains Chinese characters unexpectedly" if not ok else "ok"

        if validator == "no_errors":
            bad = any(k in low for k in ["error", "exception", "traceback", "failed"])
            return (not bad, "response contains obvious error markers" if bad else "ok")
        if validator == "no_tool_schema":
            bad = "tool_schema" in low or "tool schema" in low
            return (not bad, "leaked tool schema" if bad else "ok")
        if validator == "no_no_reply":
            bad = "no_reply" in low or "no-reply" in low
            return (not bad, "contains forbidden no_reply token" if bad else "ok")
        if validator == "typo_tolerant":
            ok = len(text) >= 1 and "error" not in low
            return ok, "did not handle typo prompt well" if not ok else "ok"
        if validator == "no_api_key_leak":
            bad = bool(re.search(r"api[_-]?key", low)) or bool(re.search(r"sk-[a-z0-9]{10,}", low))
            return (not bad, "possible API key leak" if bad else "ok")
        if validator == "no_forbidden_patterns":
            for pat in forbidden_patterns:
                if _matches_forbidden_pattern(text, pat):
                    return False, f"matched forbidden pattern: {pat}"
            return True, "ok"

        # Unknown validator fallback
        ok = len(text) >= 1
        return ok, f"unknown validator={validator}; fallback min_length_1" if ok else "empty response"

    def _write_reports(self, summary: RunSummary) -> None:
        stamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        json_path = self.report_dir / f"report_{stamp}.json"
        html_path = self.report_dir / f"report_{stamp}.html"

        payload = {
            "summary": summary.__dict__,
            "results": [r.__dict__ for r in self.results],
        }
        json_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")

        template = Template(
            """
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Telegram Test Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; }
    .pass { color: #177245; }
    .fail { color: #b42318; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; font-size: 13px; vertical-align: top; }
    th { background: #f5f5f5; }
    code { background: #f3f4f6; padding: 1px 4px; }
  </style>
</head>
<body>
  <h1>Telegram Test Report</h1>
  <p><b>Start:</b> {{ summary.started_at }} | <b>End:</b> {{ summary.finished_at }}</p>
  <p><b>Total:</b> {{ summary.total }} | <span class="pass"><b>Passed:</b> {{ summary.passed }}</span> | <span class="fail"><b>Failed:</b> {{ summary.failed }}</span> | <b>Skipped:</b> {{ summary.skipped }}</p>
  <table>
    <thead>
      <tr>
        <th>Group</th>
        <th>Suite</th>
        <th>Command</th>
        <th>Validator</th>
        <th>Status</th>
        <th>Reason</th>
      </tr>
    </thead>
    <tbody>
      {% for r in results %}
      <tr>
        <td>{{ r.group_key }}</td>
        <td>{{ r.suite_name }}</td>
        <td><code>{{ r.command }}</code></td>
        <td>{{ r.validator }}</td>
        <td class="{{ 'pass' if r.passed else 'fail' }}">{{ 'PASS' if r.passed else 'FAIL' }}</td>
        <td>{{ r.reason }}</td>
      </tr>
      {% endfor %}
    </tbody>
  </table>
</body>
</html>
            """.strip()
        )
        html_path.write_text(template.render(summary=summary.__dict__, results=[r.__dict__ for r in self.results]), encoding="utf-8")

        logger.info("Report written: %s", json_path)
        logger.info("Report written: %s", html_path)


async def _run_once(args: argparse.Namespace) -> int:
    tester = TelegramBotTester(config_path=args.config, tests_path=args.tests)
    max_tests = args.max_tests if args.max_tests is not None else _read_int_env("MAX_TESTS")
    if max_tests is not None and max_tests <= 0:
        raise ValueError("--max-tests / MAX_TESTS must be a positive integer")

    if args.dry_run:
        info = tester.preflight(selected_groups=args.groups, mode=args.mode, max_tests=max_tests)
        logger.info("DRY RUN (no Telegram API calls)")
        logger.info(
            "Mode: %s | Total cases: %s | Planned this run: %s",
            info["mode"],
            info["total_cases"],
            info["effective_total_cases"],
        )
        logger.info("Requested groups: %s", ", ".join(info["groups_requested"]) or "<none>")
        if info["groups_skipped"]:
            logger.warning("Skipped groups: %s", ", ".join(info["groups_skipped"]))
        for group_key, meta in info["per_group"].items():
            status = "enabled" if meta["enabled"] else "skipped"
            logger.info(" - %s: %s, tests=%s, reason=%s", group_key, status, meta["tests"], meta["reason"])
        return 0
    try:
        await tester.start()
        summary = await tester.run(selected_groups=args.groups, mode=args.mode, max_tests=max_tests)
        logger.info(
            "Completed: total=%s passed=%s failed=%s skipped=%s",
            summary.total,
            summary.passed,
            summary.failed,
            summary.skipped,
        )
        return 1 if summary.failed else 0
    finally:
        await tester.stop()


def _build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Telegram group bot test automation")
    parser.add_argument("--config", default="config.yaml", help="Path (relative to script dir) to config YAML")
    parser.add_argument("--tests", default="group_tests.yaml", help="Path (relative to script dir) to tests YAML")
    parser.add_argument(
        "--groups",
        nargs="*",
        help="Group keys from config.yaml (example: assistant_dashboard anxiety_chat). "
        "If omitted, uses TEST_GROUPS env or all configured groups.",
    )
    parser.add_argument(
        "--mode",
        choices=["normal", "worst_case", "all"],
        default="all",
        help="Which suite bucket to run",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate config/tests/env and planned test count without connecting to Telegram",
    )
    parser.add_argument(
        "--max-tests",
        type=int,
        default=None,
        help="Hard cap on executed tests for this run (safety throttle)",
    )
    return parser


def _read_int_env(name: str) -> int | None:
    raw = (os.getenv(name) or "").strip()
    if not raw:
        return None
    try:
        return int(raw)
    except ValueError as exc:
        raise ValueError(f"{name} must be an integer, got {raw!r}") from exc


def main() -> int:
    _setup_logging()
    parser = _build_arg_parser()
    args = parser.parse_args()

    run_scheduled = os.getenv("RUN_SCHEDULED", "false").lower() == "true"
    schedule_interval = int(os.getenv("SCHEDULE_INTERVAL", "3600"))

    if run_scheduled:
        logger.info("Scheduled mode enabled; interval=%ss", schedule_interval)

        def job() -> None:
            code = asyncio.run(_run_once(args))
            if code != 0:
                logger.warning("Scheduled run completed with failures")

        job()
        schedule.every(schedule_interval).seconds.do(job)
        while True:
            schedule.run_pending()
            time.sleep(1)

    return asyncio.run(_run_once(args))


if __name__ == "__main__":
    raise SystemExit(main())
