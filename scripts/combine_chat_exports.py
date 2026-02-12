#!/usr/bin/env python3
"""Combine Telegram chat exports and produce an issue audit report."""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path("/home/devbox/.openclaw")
EXPORT_GLOB = "datat/ChatExport_2026-02-12*/result.json"
OUT_COMBINED = ROOT / "datat/combined_chat_story.json"
OUT_AUDIT = ROOT / "datat/combined_chat_issue_audit.json"


ISSUE_PATTERNS = {
    "identity_doc_reference": re.compile(r"\b(?:IDENTITY|USER|HEARTBEAT|SOUL|BOOTSTRAP|MEMORY|MEMORY_POLICY)\.md\b", re.I),
    "identity_doc_url": re.compile(r"https?://(?:identity|user|heartbeat|soul|bootstrap|memory)\.md/?", re.I),
    "wrapper_user_assistant": re.compile(r"</?(?:user|assistant|message)\b[^>]*>", re.I),
    "wrapper_translation": re.compile(r"</?translation\b[^>]*>", re.I),
    "wrapper_reply": re.compile(r"</?_?reply\b[^>]*>", re.I),
    "wrapper_no_reply_tag": re.compile(r"</?no_reply\b[^>]*>", re.I),
    "no_reply_bare": re.compile(r"^\s*NO_REPLY\s*$", re.I),
    "wrapper_bot_action": re.compile(r"</?bot_action\b[^>]*>", re.I),
    "wrapper_begin_inference": re.compile(r"</?(?:begin_inference|end_inference)\b[^>]*>", re.I),
    "wrapper_extra": re.compile(r"</?extra\b[^>]*>", re.I),
    "wrapper_transcript_speech": re.compile(r"</?(?:transcript|speech|speaker)\b[^>]*>", re.I),
    "tool_wrapper_web_search": re.compile(r"\bweb_search\b|</?searchWeb\b[^>]*>", re.I),
    "unknown_command_static": re.compile(r"Unknown command\. Use /help\.", re.I),
    "private_path_leak": re.compile(r"/home/devbox/\.openclaw", re.I),
}


def extract_text(msg: dict) -> str:
    text = msg.get("text")
    if isinstance(text, str):
        return text
    if isinstance(text, list):
        parts = []
        for p in text:
            if isinstance(p, str):
                parts.append(p)
            elif isinstance(p, dict):
                t = p.get("text")
                if isinstance(t, str):
                    parts.append(t)
        return "".join(parts)
    return ""


def main() -> int:
    files = sorted(ROOT.glob(EXPORT_GLOB))
    if not files:
        raise SystemExit(f"No export files found with pattern: {EXPORT_GLOB}")

    combined = {
        "source_glob": EXPORT_GLOB,
        "file_count": len(files),
        "groups": [],
    }
    issue_counts: Counter[str] = Counter()
    issue_examples: dict[str, list[dict]] = {k: [] for k in ISSUE_PATTERNS}

    for fp in files:
        data = json.loads(fp.read_text(encoding="utf-8"))
        messages = data.get("messages", [])
        group_entry = {
            "source_file": str(fp.relative_to(ROOT)),
            "id": data.get("id"),
            "name": data.get("name"),
            "type": data.get("type"),
            "message_count": len(messages),
            "messages": messages,
        }
        combined["groups"].append(group_entry)

        for i, msg in enumerate(messages):
            if not isinstance(msg, dict):
                continue
            text = extract_text(msg)
            if not text:
                continue
            for issue, pat in ISSUE_PATTERNS.items():
                if pat.search(text):
                    issue_counts[issue] += 1
                    if len(issue_examples[issue]) < 5:
                        issue_examples[issue].append(
                            {
                                "source_file": str(fp.relative_to(ROOT)),
                                "message_index": i,
                                "message_id": msg.get("id"),
                                "snippet": text[:300],
                            }
                        )

    OUT_COMBINED.write_text(
        json.dumps(combined, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    audit = {
        "source_glob": EXPORT_GLOB,
        "file_count": len(files),
        "group_count": len(combined["groups"]),
        "total_messages": sum(int(g["message_count"]) for g in combined["groups"]),
        "issue_counts": dict(issue_counts),
        "issue_examples": issue_examples,
    }
    OUT_AUDIT.write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {OUT_COMBINED}")
    print(f"Wrote {OUT_AUDIT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

