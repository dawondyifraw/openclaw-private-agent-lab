#!/usr/bin/env bash
# Patch installed OpenClaw bundle to enforce Telegram slash-command default-deny
# while allowing a small explicit allowlist through to agent/plugin handlers.
#
# Marker: OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1
set -euo pipefail

DIST_FILE="${OPENCLAW_REPLY_DIST_FILE:-$HOME/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js}"

if [[ ! -f "${DIST_FILE}" ]]; then
  echo "FAIL: missing bundle: ${DIST_FILE}" >&2
  exit 1
fi

if rg -q "OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1" "${DIST_FILE}" \
  && rg -q "OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_1" "${DIST_FILE}" \
  && rg -Fq 'chatIdStrRaw.startsWith("telegram:") ? chatIdStrRaw.slice(9) : chatIdStrRaw' "${DIST_FILE}" \
  && rg -Fq '/^(?:\/(?:help|status|model))(?:@[A-Za-z0-9_]+)?(?:\s|$)/i.test(normalizedCommandBody)' "${DIST_FILE}" \
  && rg -Fq '/^\/dash(?:@[A-Za-z0-9_]+)?(?:\s|$)/i.test(normalizedCommandBody)' "${DIST_FILE}" \
  && rg -Fq 'if (/^\/dashboard(?:@[A-Za-z0-9_]+)?(?:\s|$)/i.test(b)) params.command.commandBodyNormalized = b.replace(/^\/dashboard/i, "/dash");' "${DIST_FILE}"; then
  echo "PASS: telegram command allowlist patches already present"
  exit 0
fi

cp "${DIST_FILE}" "${DIST_FILE}.bak.cmdallowlist.$(date +%Y%m%d%H%M%S)"

python3 - "${DIST_FILE}" <<'PY'
import pathlib, re, sys

p = pathlib.Path(sys.argv[1])
t = p.read_text()

# Alias /dashboard -> /dash so Telegram users can type either.
# Must run before unknown-slash guard, otherwise /dashboard gets blocked.
alias_block_v0 = (
    "\t/* OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_0\n"
    "\t   Alias /dashboard to /dash (dashboard skill).\n"
    "\t*/\n"
    "\ttry {\n"
    "\t\tconst b = String(params.command.commandBodyNormalized ?? \"\");\n"
    "\t\tif (/^\\/dashboard(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(b)) params.command.commandBodyNormalized = b.replace(/^\\/dashboard/i, \"/dash\");\n"
    "\t\tconst rb = String(params.command.rawBodyNormalized ?? \"\");\n"
    "\t\tif (/^\\/dashboard(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(rb)) params.command.rawBodyNormalized = rb.replace(/^\\/dashboard/i, \"/dash\");\n"
    "\t} catch {}\n"
)
alias_block_v1 = alias_block_v0.replace("OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_0", "OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_1")

# Telegram command allowlist (default deny).
allowlist_marker = "OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1"
allowlist_insert = (
    "\t\t/* OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1\n"
    "\t\t   Default deny: unknown slash commands do not reach the LLM.\n"
    "\t\t   Allowlist permits only explicitly approved commands to fall through.\n"
    "\t\t*/\n"
    "\t\tconst allowGlobal = /^(?:\\/(?:help|status|model))(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(normalizedCommandBody) || /^(?:\\/(?:new|reset))(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(normalizedCommandBody);\n"
    "\t\tconst cmdChannel = String(params.command.channel ?? params.command.surface ?? \"\").trim().toLowerCase();\n"
    "\t\tconst chatIdStrRaw = String(params.command.to ?? \"\");\n"
    "\t\t// Command context uses To=\"telegram:<chatId>\"; normalize to raw chat id for comparisons.\n"
    "\t\tconst chatIdStr = chatIdStrRaw.startsWith(\"telegram:\") ? chatIdStrRaw.slice(9) : chatIdStrRaw;\n"
    "\t\tconst assistantDashGroupId = String(process.env.OPENCLAW_ASSISTANT_DASH_GROUP_ID || \"TG_GROUP_ASSISTANT_DASHBOARD_ID\");\n"
    "\t\tconst allowDashboardGroup = cmdChannel === \"telegram\" && chatIdStr === assistantDashGroupId && (\n"
    "\t\t\t/^\\/dash(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(normalizedCommandBody) ||\n"
    "\t\t\t/^\\/task(?:@[A-Za-z0-9_]+)?\\s+(?:list|add\\s+\\S[\\s\\S]*|done\\s+\\S+)(?:\\s|$)/i.test(normalizedCommandBody) ||\n"
    "\t\t\t/^\\/remind(?:@[A-Za-z0-9_]+)?\\s+(?:list|cancel\\s+\\S+|at\\s+\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}\\s+\\S[\\s\\S]*)(?:\\s|$)/i.test(normalizedCommandBody)\n"
    "\t\t);\n"
    "\t\tconst isKnownSlashCommand = allowGlobal || allowDashboardGroup;\n"
    "\t\tif (isKnownSlashCommand) return { shouldContinue: true };\n"
)

# Insert allowlist gating before the unknown-slash fallback reply.
if allowlist_marker not in t:
    cmd_anchor = "\tif (normalizedCommandBody.startsWith(\"/\")) {\n"
    if cmd_anchor not in t:
        raise SystemExit("command guard anchor not found for allowlist insertion")
    t = t.replace(cmd_anchor, cmd_anchor + allowlist_insert, 1)
else:
    # Self-heal: earlier allowlist insertion used `const channel = ...` which collided with
    # the existing debug block's `const channel = ...`.
    t = re.sub(
        r"(/\\* OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1[\\s\\S]*?)\\t\\tconst channel = String\\(\\s*params\\.command\\.channel\\s*\\?\\?\\s*params\\.command\\.surface\\s*\\?\\?\\s*\\\"\\\"\\s*\\)\\.trim\\(\\)\\.toLowerCase\\(\\);",
        r"\\1\\t\\tconst cmdChannel = String(params.command.channel ?? params.command.surface ?? \\\"\\\").trim().toLowerCase();",
        t,
        count=1,
    )
    t = re.sub(
        r"(/\\* OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1[\\s\\S]*?)\\t\\tconst allowDashboardGroup = channel === \\\"telegram\\\"",
        r"\\1\\t\\tconst allowDashboardGroup = cmdChannel === \\\"telegram\\\"",
        t,
        count=1,
    )
    if 'chatIdStrRaw.startsWith("telegram:") ? chatIdStrRaw.slice(9) : chatIdStrRaw' not in t:
        t = re.sub(
            r"(/\\* OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1[\\s\\S]*?)\\t\\tconst chatIdStr = String\\(params\\.command\\.to\\s*\\?\\?\\s*\\\"\\\"\\);",
            r"\\1\\t\\tconst chatIdStrRaw = String(params.command.to ?? \\\"\\\");\n\\t\\t// Command context uses To=\\\"telegram:<chatId>\\\"; normalize to raw chat id for comparisons.\n\\t\\tconst chatIdStr = chatIdStrRaw.startsWith(\\\"telegram:\\\") ? chatIdStrRaw.slice(9) : chatIdStrRaw;",
            t,
            count=1,
        )

# Self-heal: remove any prior alias blocks and re-insert at the correct (handleCommands) location.
if "OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_0" in t or "OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_1" in t:
    t = t.replace(alias_block_v0, "")
    t = t.replace(alias_block_v1, "")

# Self-heal legacy alias implementation that only handled bare /dashboard.
t = t.replace(
    'if (b === "/dashboard" || b.startsWith("/dashboard ")) params.command.commandBodyNormalized = "/dash" + b.slice(10);',
    'if (/^\\/dashboard(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(b)) params.command.commandBodyNormalized = b.replace(/^\\/dashboard/i, "/dash");',
)
t = t.replace(
    'if (rb === "/dashboard" || rb.startsWith("/dashboard ")) params.command.rawBodyNormalized = "/dash" + rb.slice(10);',
    'if (/^\\/dashboard(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(rb)) params.command.rawBodyNormalized = rb.replace(/^\\/dashboard/i, "/dash");',
)

# Self-heal legacy allowlist patterns that did not accept /command@bot form.
t = t.replace(
    'const allowGlobal = /^(?:\\/help|\\/status|\\/model)(?:\\s|$)/i.test(normalizedCommandBody) || /^\\/(?:new|reset)(?:\\s|$)/i.test(normalizedCommandBody);',
    'const allowGlobal = /^(?:\\/(?:help|status|model))(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(normalizedCommandBody) || /^(?:\\/(?:new|reset))(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(normalizedCommandBody);',
)
t = t.replace(
    '/^\\/dash(?:\\s|$)/i.test(normalizedCommandBody)',
    '/^\\/dash(?:@[A-Za-z0-9_]+)?(?:\\s|$)/i.test(normalizedCommandBody)',
)
t = t.replace(
    '/^\\/task\\s+(?:list|add\\s+\\S[\\s\\S]*|done\\s+\\S+)(?:\\s|$)/i.test(normalizedCommandBody)',
    '/^\\/task(?:@[A-Za-z0-9_]+)?\\s+(?:list|add\\s+\\S[\\s\\S]*|done\\s+\\S+)(?:\\s|$)/i.test(normalizedCommandBody)',
)
t = t.replace(
    '/^\\/remind\\s+(?:list|cancel\\s+\\S+|at\\s+\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}\\s+\\S[\\s\\S]*)(?:\\s|$)/i.test(normalizedCommandBody)',
    '/^\\/remind(?:@[A-Za-z0-9_]+)?\\s+(?:list|cancel\\s+\\S+|at\\s+\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}\\s+\\S[\\s\\S]*)(?:\\s|$)/i.test(normalizedCommandBody)',
)

if "OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_1" not in t:
    anchor = (
        "\tconst allowTextCommands = shouldHandleTextCommands({\n"
        "\t\tcfg: params.cfg,\n"
        "\t\tsurface: params.command.surface,\n"
        "\t\tcommandSource: params.ctx.CommandSource\n"
        "\t});\n"
    )
    if anchor not in t:
        raise SystemExit("anchor not found for /dashboard alias patch")
    t = t.replace(anchor, alias_block_v1 + anchor, 1)

p.write_text(t)
PY

if ! rg -q "OPENCLAW_TELEGRAM_COMMAND_ALLOWLIST_V1" "${DIST_FILE}"; then
  echo "FAIL: allowlist marker missing after patch" >&2
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_DASHBOARD_ALIAS_V1_1" "${DIST_FILE}"; then
  echo "FAIL: /dashboard alias marker missing after patch" >&2
  exit 1
fi
if ! rg -Fq 'chatIdStrRaw.startsWith("telegram:") ? chatIdStrRaw.slice(9) : chatIdStrRaw' "${DIST_FILE}"; then
  echo "FAIL: allowlist chatId normalization missing after patch" >&2
  exit 1
fi
if ! rg -Fq '/^(?:\/(?:help|status|model))(?:@[A-Za-z0-9_]+)?(?:\s|$)/i.test(normalizedCommandBody)' "${DIST_FILE}"; then
  echo "FAIL: global /command@bot allowlist pattern missing after patch" >&2
  exit 1
fi
if ! rg -Fq '/^\/dash(?:@[A-Za-z0-9_]+)?(?:\s|$)/i.test(normalizedCommandBody)' "${DIST_FILE}"; then
  echo "FAIL: /dash@bot allowlist pattern missing after patch" >&2
  exit 1
fi

echo "PASS: telegram command allowlist patches applied"
