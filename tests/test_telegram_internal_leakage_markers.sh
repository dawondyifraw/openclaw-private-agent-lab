#!/usr/bin/env bash
# STRICT: fail if recent Telegram session JSONL contains internal diagnostic/tool/runtime leakage.
# This is global across Telegram: groups + DMs + all agents (non-main and main).
#
# Cutoff-aware: only enforces after the installed OpenClaw bundle mtime, so historical sessions
# don't fail strict forever.

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

WINDOW_MINUTES="${OPENCLAW_RECENT_TELEGRAM_LEAK_WINDOW_MINUTES:-30}"

node <<'NODE'
const fs = require('fs');
const path = require('path');

const baseDir = '/home/devbox/.openclaw';
const windowMinutes = Number(process.env.OPENCLAW_RECENT_TELEGRAM_LEAK_WINDOW_MINUTES || 30);
const windowCutoffMs = Date.now() - windowMinutes * 60 * 1000;

const distFile = '/home/devbox/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js';
let effectiveAfterMs = 0;
try { effectiveAfterMs = fs.statSync(distFile).mtimeMs - 60_000; } catch { effectiveAfterMs = 0; }
const cutoffMs = Math.max(windowCutoffMs, effectiveAfterMs);

const forbiddenRe = new RegExp([
  'tool call validation failed',
  'attempted to call tool',
  'not in request\\.tools',
  'provide either sessionkey or label',
  'for using `sessionkey`',
  'for using `label`',
  'gateway timeout',
  'ws://127\\.0\\.0\\.1',
  '\\\\bRun ID:',
  '\\\\bStatus:\\\\s*error',
  'commands\\\\.restart',
  'set commands\\\\.restart=true',
  '\\\\bNOBELLA_ERROR\\\\b',
  '\\\\bNO_?CONTEXT\\\\b',
  '\\\\bNO_?CONTENT\\\\b',
  '\\\\bNO_MESSAGE_CONTENT_HERE\\\\b',
  '\\\\bNO_DATA_FOUND\\\\b',
  '\\\\bNO_API_KEY\\\\b',
  '<tools>',
  '<toolbox>',
  '\\\\bfunction_call\\\\b',
  '^\\\\s*\\\\.?MEDIA:',
].join('|'), 'im');

function looksLikeToolJsonBlock(text) {
  const t = String(text || '');
  if (!t.includes('```')) return false;
  // Heuristic: fenced block with tool-ish fields.
  return /```[\\s\\S]*?(\"name\"\\s*:|\"arguments\"\\s*:|\"toolCall\"\\s*:)[\\s\\S]*?```/i.test(t);
}

function listJsonlFiles(agentsDir) {
  const out = [];
  if (!fs.existsSync(agentsDir)) return out;
  for (const ent of fs.readdirSync(agentsDir, { withFileTypes: true })) {
    if (!ent.isDirectory()) continue;
    const sessionsDir = path.join(agentsDir, ent.name, 'sessions');
    if (!fs.existsSync(sessionsDir)) continue;
    for (const f of fs.readdirSync(sessionsDir)) {
      if (f.endsWith('.jsonl')) out.push({ agent: ent.name, file: path.join(sessionsDir, f) });
    }
  }
  return out;
}

function parseJsonl(file) {
  const lines = fs.readFileSync(file, 'utf8').split(/\\r?\\n/).filter(Boolean);
  const entries = [];
  for (const line of lines) {
    try { entries.push(JSON.parse(line)); } catch {}
  }
  return entries;
}

function isTelegramSession(entries) {
  // Telegram envelope appears in user messages; also /dock_telegram is a Telegram-origin marker.
  for (const e of entries) {
    const msg = e && e.message;
    if (!msg || msg.role !== 'user') continue;
    const blocks = Array.isArray(msg.content) ? msg.content : [];
    for (const b of blocks) {
      if (!b || b.type !== 'text' || typeof b.text !== 'string') continue;
      const s = b.text;
      if (s.includes('[Telegram') && s.includes('id:')) return true;
      if (s.startsWith('/dock_telegram')) return true;
    }
  }
  return false;
}

const agentsDir = path.join(baseDir, 'agents');
const files = listJsonlFiles(agentsDir);

const hits = [];
for (const { agent, file } of files) {
  let st;
  try { st = fs.statSync(file); } catch { continue; }
  if (st.mtimeMs < cutoffMs) continue;

  const entries = parseJsonl(file);
  if (!isTelegramSession(entries)) continue;

  for (const e of entries) {
    const ts = e?.timestamp ? Date.parse(e.timestamp) : null;
    if (!ts || ts < cutoffMs) continue;

    // Catch error messages (these sometimes get mirrored out).
    if (typeof e?.message?.errorMessage === 'string' && forbiddenRe.test(e.message.errorMessage)) {
      hits.push({ agent, file, ts: e.timestamp, kind: 'errorMessage', sample: e.message.errorMessage.slice(0, 200) });
      continue;
    }

    const msg = e?.message;
    if (!msg) continue;
    const blocks = Array.isArray(msg.content) ? msg.content : [];
    for (const b of blocks) {
      if (!b) continue;
      if (b.type === 'text' && typeof b.text === 'string') {
        if (forbiddenRe.test(b.text) || looksLikeToolJsonBlock(b.text)) {
          hits.push({ agent, file, ts: e.timestamp, kind: 'text', sample: b.text.slice(0, 200) });
          break;
        }
      }
    }
  }
}

if (hits.length) {
  console.log('FAIL: Telegram outbound leakage markers found in recent session JSONL');
  console.log(`cutoff=${new Date(cutoffMs).toISOString()} (window=${windowMinutes}m)`);
  for (const h of hits.slice(0, 10)) {
    console.log(`- agent=${h.agent} ts=${h.ts} kind=${h.kind} file=${h.file}`);
    console.log(`  sample=${JSON.stringify(h.sample)}`);
  }
  process.exit(1);
}

console.log(`PASS: no Telegram outbound leakage markers found in recent sessions (cutoff=${new Date(cutoffMs).toISOString()})`);
NODE
