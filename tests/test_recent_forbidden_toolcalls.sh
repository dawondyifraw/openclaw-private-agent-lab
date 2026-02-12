#!/usr/bin/env bash
# STRICT: Fail if recent Telegram session JSONL contains forbidden tool calls
# (e.g. tts/sessions_send) for any non-main agent.
#
# Notes:
# - This is cutoff-aware: it only enforces after the installed OpenClaw bundle mtime,
#   so historical session files don't fail strict forever.

set -euo pipefail

MODE="${OPENCLAW_TEST_MODE:-default}"

if ! command -v node >/dev/null 2>&1; then
  if [ "$MODE" = "strict" ]; then
    echo "FAIL: node is required for this test"
    exit 1
  fi
  echo "SKIP: node not available"
  exit 0
fi

WINDOW_MINUTES="${OPENCLAW_RECENT_TOOLCALL_WINDOW_MINUTES:-15}"

node <<'NODE'
const fs = require('fs');
const path = require('path');

const baseDir = '/home/devbox/.openclaw';
const windowMinutes = Number(process.env.OPENCLAW_RECENT_TOOLCALL_WINDOW_MINUTES || 15);
const windowCutoffMs = Date.now() - windowMinutes * 60 * 1000;

const distFile = '/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js';
let effectiveAfterMs = 0;
try {
  effectiveAfterMs = fs.statSync(distFile).mtimeMs - 60_000;
} catch {
  effectiveAfterMs = 0;
}
const cutoffMs = Math.max(windowCutoffMs, effectiveAfterMs);

const forbidden = new Set([
  'tts',
  'sessions_send',
  'sessions_spawn',
  'sessions_list',
  'sessions_history',
  'message',
]);

function listJsonlFiles(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!ent.isDirectory()) continue;
    const sessionsDir = path.join(dir, ent.name, 'sessions');
    if (!fs.existsSync(sessionsDir)) continue;
    for (const f of fs.readdirSync(sessionsDir)) {
      if (f.endsWith('.jsonl')) out.push({ agent: ent.name, file: path.join(sessionsDir, f) });
    }
  }
  return out;
}

function parseJsonl(file) {
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/).filter(Boolean);
  const entries = [];
  for (const line of lines) {
    try { entries.push(JSON.parse(line)); } catch {}
  }
  return entries;
}

function isTelegramSession(entries) {
  for (const e of entries) {
    const msg = e && e.message;
    if (!msg || msg.role !== 'user') continue;
    const blocks = Array.isArray(msg.content) ? msg.content : [];
    for (const b of blocks) {
      if (!b || b.type !== 'text' || typeof b.text !== 'string') continue;
      if (b.text.includes('[Telegram') && b.text.includes('id:')) return true;
    }
  }
  return false;
}

const agentsDir = path.join(baseDir, 'agents');
const files = listJsonlFiles(agentsDir);

const findings = [];
for (const { agent, file } of files) {
  if (agent === 'main') continue;
  let st;
  try { st = fs.statSync(file); } catch { continue; }
  if (st.mtimeMs < cutoffMs) continue;

  const entries = parseJsonl(file);
  if (!isTelegramSession(entries)) continue;

  for (const e of entries) {
    const ts = e?.timestamp ? Date.parse(e.timestamp) : null;
    if (!ts || ts < cutoffMs) continue;
    const msg = e?.message;
    if (!msg || msg.role !== 'assistant') continue;
    const blocks = Array.isArray(msg.content) ? msg.content : [];
    for (const b of blocks) {
      if (!b || b.type !== 'toolCall') continue;
      const name = String(b.name || '').trim().toLowerCase();
      if (forbidden.has(name)) {
        findings.push({ agent, file, tool: name, timestamp: e.timestamp, id: e.id });
      }
    }
  }
}

if (findings.length) {
  console.log('FAIL: forbidden toolCall(s) found in recent Telegram sessions');
  console.log(`cutoff=${new Date(cutoffMs).toISOString()} (window=${windowMinutes}m, distMtime=${effectiveAfterMs ? new Date(effectiveAfterMs).toISOString() : 'n/a'})`);
  for (const f of findings.slice(0, 10)) {
    console.log(`- agent=${f.agent} tool=${f.tool} ts=${f.timestamp} file=${f.file} entryId=${f.id}`);
  }
  process.exit(1);
}

console.log(`PASS: no forbidden toolCall entries found in recent Telegram sessions (cutoff=${new Date(cutoffMs).toISOString()})`);
NODE

