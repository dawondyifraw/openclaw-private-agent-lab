#!/usr/bin/env bash
# Patch installed OpenClaw Telegram outbound sanitizer to strip wrapper artifacts
# like <reply>...</reply> and <_REPLY>...</_REPLY> before delivery.
set -euo pipefail

DIST_FILE="${OPENCLAW_REPLY_DIST_FILE:-$HOME/.local/lib/node_modules/openclaw/dist/reply-DptDUVRg.js}"

if [[ ! -f "${DIST_FILE}" ]]; then
  echo "FAIL: missing bundle: ${DIST_FILE}" >&2
  exit 1
fi

if rg -q "OPENCLAW_TELEGRAM_REPLY_WRAPPER_STRIP_V1_1" "${DIST_FILE}" \
  && rg -q "OPENCLAW_TELEGRAM_TEXTMODE_EMOJI_V1_0" "${DIST_FILE}" \
  && rg -q "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_1" "${DIST_FILE}" \
  && rg -q "OPENCLAW_TELEGRAM_INTERNAL_MARKER_SUPPRESS_V1_0" "${DIST_FILE}" \
  && rg -q "OPENCLAW_TELEGRAM_SENDMESSAGE_CHOKEPOINT_V1_3" "${DIST_FILE}" \
  && rg -q "OPENCLAW_DIAG_ERROR_REDACTION_V1_0" "${DIST_FILE}"; then
  echo "PASS: telegram runtime patches already present"
  exit 0
fi

cp "${DIST_FILE}" "${DIST_FILE}.bak.replywrapper.$(date +%Y%m%d%H%M%S)"

python3 - "${DIST_FILE}" <<'PY'
import pathlib, re, sys

p = pathlib.Path(sys.argv[1])
t = p.read_text()

# Upgrade marker if previous version exists.
t = t.replace(
    "OPENCLAW_TELEGRAM_REPLY_WRAPPER_STRIP_V1_0",
    "OPENCLAW_TELEGRAM_REPLY_WRAPPER_STRIP_V1_1",
)

# Upgrade existing wrapper regexes to support optional leading underscore.
t = t.replace(
    r'const wrappedReplyMatch = t.match(/^\s*<reply[^>]*>([\s\S]*?)<\/reply>\s*$/i);',
    r'const wrappedReplyMatch = t.match(/^\s*<_?reply[^>]*>([\s\S]*?)<\/_?reply>\s*$/i);',
)
t = t.replace(
    r'const replyWrapperHits = countAndReplace(/<\/?reply[^>]*>/gi, "");',
    r'const replyWrapperHits = countAndReplace(/<\/?_?reply[^>]*>/gi, "");',
)

# If no wrapper block exists yet, inject full v1.1 block.
if "const wrappedReplyMatch = t.match(/^\\s*<_?reply[^>]*>([\\s\\S]*?)<\\/_?reply>\\s*$/i);" not in t:
    anchor = (
        "\tconst countAndReplace = (regex, replacement) => {\n"
        "\t\tconst matches = t.match(regex);\n"
        "\t\tif (matches && matches.length > 0) strippedCount += matches.length;\n"
        "\t\tt = t.replace(regex, replacement);\n"
        "\t\treturn matches ? matches.length : 0;\n"
        "\t};\n"
        "\t// Global suppression layer (Telegram groups + DMs), unless explicitly overridden.\n"
    )
    insert = (
        "\tconst countAndReplace = (regex, replacement) => {\n"
        "\t\tconst matches = t.match(regex);\n"
        "\t\tif (matches && matches.length > 0) strippedCount += matches.length;\n"
        "\t\tt = t.replace(regex, replacement);\n"
        "\t\treturn matches ? matches.length : 0;\n"
        "\t};\n"
        "\t/* OPENCLAW_TELEGRAM_REPLY_WRAPPER_STRIP_V1_1\n"
        "\t   Strip wrapper artifacts like <reply>...</reply> and <_REPLY>...</_REPLY>.\n"
        "\t*/\n"
        "\tconst wrappedReplyMatch = t.match(/^\\s*<_?reply[^>]*>([\\s\\S]*?)<\\/_?reply>\\s*$/i);\n"
        "\tif (wrappedReplyMatch) {\n"
        "\t\tt = wrappedReplyMatch[1] ?? \"\";\n"
        "\t\tstrippedCount += 2;\n"
        "\t}\n"
        "\tconst replyWrapperHits = countAndReplace(/<\\/?_?reply[^>]*>/gi, \"\");\n"
        "\t// Global suppression layer (Telegram groups + DMs), unless explicitly overridden.\n"
    )
    if anchor in t:
        t = t.replace(anchor, insert, 1)
    else:
        raise SystemExit("anchor not found for wrapper insertion")

# Ensure dropReason branch exists once.
drop_target = 'else if (ttsLeakHits + mediaNoteHits > 0) dropReason = "MEDIA_LEAK";'
drop_insert = (
    'else if (replyWrapperHits > 0) dropReason = "WRAPPER_ARTIFACT";\n'
    '\t\t\telse if (ttsLeakHits + mediaNoteHits > 0) dropReason = "MEDIA_LEAK";'
)
if 'else if (replyWrapperHits > 0) dropReason = "WRAPPER_ARTIFACT";' not in t:
    if drop_target not in t:
        raise SystemExit("dropReason line not found")
    t = t.replace(drop_target, drop_insert, 1)

# Repair possible bad escaped newline artifact from earlier patch attempts.
t = t.replace(
    'else if (replyWrapperHits > 0) dropReason = "WRAPPER_ARTIFACT";\\n\\t\\t\\telse if (ttsLeakHits + mediaNoteHits > 0) dropReason = "MEDIA_LEAK";',
    'else if (replyWrapperHits > 0) dropReason = "WRAPPER_ARTIFACT";\n\t\t\telse if (ttsLeakHits + mediaNoteHits > 0) dropReason = "MEDIA_LEAK";',
)

# Ensure Telegram emoji/text plain-mode guard:
old_send_block = """\tconst htmlText = (opts?.textMode ?? \"markdown\") === \"html\" ? text : markdownToTelegramHtml(text);
\ttry {
\t\treturn (await withTelegramApiErrorLogging({
\t\t\toperation: \"sendMessage\",
\t\t\truntime,
\t\t\tshouldLog: (err) => !PARSE_ERR_RE.test(formatErrorMessage(err)),
\t\t\tfn: () => bot.api.sendMessage(chatId, htmlText, {
\t\t\t\tparse_mode: \"HTML\",
\t\t\t\t...linkPreviewOptions ? { link_preview_options: linkPreviewOptions } : {},
\t\t\t\t...opts?.replyMarkup ? { reply_markup: opts.replyMarkup } : {},
\t\t\t\t...baseParams
\t\t\t})
\t\t})).message_id;
\t} catch (err) {
\t\tconst errText = formatErrorMessage(err);
\t\tif (PARSE_ERR_RE.test(errText)) {
\t\t\truntime.log?.(`telegram HTML parse failed; retrying without formatting: ${errText}`);
\t\t\tconst fallbackText = opts?.plainText ?? text;
\t\t\treturn (await withTelegramApiErrorLogging({
\t\t\t\toperation: \"sendMessage\",
\t\t\t\truntime,
\t\t\t\tfn: () => bot.api.sendMessage(chatId, fallbackText, {
\t\t\t\t\t...linkPreviewOptions ? { link_preview_options: linkPreviewOptions } : {},
\t\t\t\t\t...opts?.replyMarkup ? { reply_markup: opts.replyMarkup } : {},
\t\t\t\t\t...baseParams
\t\t\t\t})
\t\t\t})).message_id;
\t\t}
\t\tthrow err;
\t}"""

new_send_block = """\t/* OPENCLAW_TELEGRAM_TEXTMODE_EMOJI_V1_0
\t   Prefer plain text (no parse_mode) when no HTML markup is needed.
\t   This keeps emoji rendering natural while preserving HTML formatting when present.
\t*/
\tconst requestedTextMode = opts?.textMode ?? \"markdown\";
\tconst htmlText = requestedTextMode === \"html\" ? text : markdownToTelegramHtml(text);
\tconst fallbackText = opts?.plainText ?? text;
\tconst shouldUseHtmlParseMode = /<\\/?[a-z][^>]*>/i.test(String(htmlText));
\ttry {
\t\treturn (await withTelegramApiErrorLogging({
\t\t\toperation: \"sendMessage\",
\t\t\truntime,
\t\t\tshouldLog: (err) => !PARSE_ERR_RE.test(formatErrorMessage(err)),
\t\t\tfn: () => bot.api.sendMessage(chatId, shouldUseHtmlParseMode ? htmlText : fallbackText, {
\t\t\t\t...shouldUseHtmlParseMode ? { parse_mode: \"HTML\" } : {},
\t\t\t\t...linkPreviewOptions ? { link_preview_options: linkPreviewOptions } : {},
\t\t\t\t...opts?.replyMarkup ? { reply_markup: opts.replyMarkup } : {},
\t\t\t\t...baseParams
\t\t\t})
\t\t})).message_id;
\t} catch (err) {
\t\tconst errText = formatErrorMessage(err);
\t\tif (PARSE_ERR_RE.test(errText)) {
\t\t\truntime.log?.(`telegram HTML parse failed; retrying without formatting: ${errText}`);
\t\t\treturn (await withTelegramApiErrorLogging({
\t\t\t\toperation: \"sendMessage\",
\t\t\t\truntime,
\t\t\t\tfn: () => bot.api.sendMessage(chatId, fallbackText, {
\t\t\t\t\t...linkPreviewOptions ? { link_preview_options: linkPreviewOptions } : {},
\t\t\t\t\t...opts?.replyMarkup ? { reply_markup: opts.replyMarkup } : {},
\t\t\t\t\t...baseParams
\t\t\t\t})
\t\t\t})).message_id;
\t\t}
\t\tthrow err;
\t}"""

if "OPENCLAW_TELEGRAM_TEXTMODE_EMOJI_V1_0" not in t:
    if old_send_block in t:
        t = t.replace(old_send_block, new_send_block, 1)
    else:
        raise SystemExit("sendTelegramText block not found for emoji textmode patch")

# Enforce Amharic output for configured Amharic chat IDs at outbound stage.
if "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_1" not in t:
    # upgrade marker when present
    t = t.replace(
        "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_0",
        "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_1",
    )
    old_block = (
        "const sanitized = sanitizeTelegramOutboundText(reply?.text ?? \"\", { isGroup: isGroupChat, suppressDiagnostics: !allowDiagnostics });\n"
        "\t\tconst sanitizedText = sanitized.text;\n"
        "\t\tconst replyToId = replyToMode === \"off\" ? void 0 : resolveTelegramReplyId(reply.replyToId);\n"
    )
    new_block = (
        "const sanitized = sanitizeTelegramOutboundText(reply?.text ?? \"\", { isGroup: isGroupChat, suppressDiagnostics: !allowDiagnostics });\n"
        "\t\tlet sanitizedText = sanitized.text;\n"
        "\t\t/* OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_1\n"
        "\t\t   Enforce Amharic outbound text for configured Amharic group chats.\n"
        "\t\t*/\n"
        "\t\tconst amharicChatIds = new Set(String(process.env.OPENCLAW_AMHARIC_CHAT_IDS || \"TG_GROUP_MERRY_ID,TG_GROUP_HELLO_ID\").split(\",\").map((v) => v.trim()).filter(Boolean));\n"
        "\t\tconst shouldEnforceAmharic = amharicChatIds.has(chatIdStr);\n"
        "\t\tif (shouldEnforceAmharic && sanitizedText && !isLikelyCommand && !/[\\u1200-\\u137F]/.test(sanitizedText)) try {\n"
        "\t\t\tconst trRes = await fetch(\"http://127.0.0.1:18790/translate/amharic\", {\n"
        "\t\t\t\tmethod: \"POST\",\n"
        "\t\t\t\theaders: { \"Content-Type\": \"application/json\" },\n"
        "\t\t\t\tbody: JSON.stringify({ text: sanitizedText })\n"
        "\t\t\t});\n"
        "\t\t\tif (trRes.ok) {\n"
        "\t\t\t\tconst trJson = await trRes.json().catch(() => ({}));\n"
        "\t\t\t\tconst translated = String(trJson?.amharic ?? \"\").trim();\n"
        "\t\t\t\tconst hasEthiopic = /[\\u1200-\\u137F]/.test(translated);\n"
        "\t\t\t\tconst looksPlaceholder = /^\\s*\\[AMHARIC TRANSLATION OF:/i.test(translated);\n"
        "\t\t\t\tif (translated && hasEthiopic && !looksPlaceholder) sanitizedText = translated;\n"
        "\t\t\t\telse sanitizedText = \"ሰላም! እንዴት ልርዳዎ?\";\n"
        "\t\t\t} else sanitizedText = \"ሰላም! እንዴት ልርዳዎ?\";\n"
        "\t\t} catch {\n"
        "\t\t\tsanitizedText = \"ሰላም! እንዴት ልርዳዎ?\";\n"
        "\t\t}\n"
        "\t\tconst replyToId = replyToMode === \"off\" ? void 0 : resolveTelegramReplyId(reply.replyToId);\n"
    )
    if old_block in t:
        t = t.replace(old_block, new_block, 1)
    else:
        # in-place upgrade path for existing v1.0 block
        t = t.replace(
            "const translated = String(trJson?.amharic ?? \"\").trim();\n\t\t\t\tif (translated) sanitizedText = translated;\n\t\t\t\telse sanitizedText = \"እባክዎ መልእክትዎን በአማርኛ ይጻፉ።\";",
            "const translated = String(trJson?.amharic ?? \"\").trim();\n\t\t\t\tconst hasEthiopic = /[\\u1200-\\u137F]/.test(translated);\n\t\t\t\tconst looksPlaceholder = /^\\s*\\[AMHARIC TRANSLATION OF:/i.test(translated);\n\t\t\t\tif (translated && hasEthiopic && !looksPlaceholder) sanitizedText = translated;\n\t\t\t\telse sanitizedText = \"ሰላም! እንዴት ልርዳዎ?\";",
        )
        t = t.replace("} else sanitizedText = \"እባክዎ መልእክትዎን በአማርኛ ይጻፉ።\";", "} else sanitizedText = \"ሰላም! እንዴት ልርዳዎ?\";")
        t = t.replace("sanitizedText = \"እባክዎ መልእክትዎን በአማርኛ ይጻፉ።\";", "sanitizedText = \"ሰላም! እንዴት ልርዳዎ?\";")
        if "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_1" not in t:
            raise SystemExit("deliverReplies sanitizedText block not found for Amharic enforcement patch")

# Expand diagnostic suppressor to include NO_DATA_PASSED marker leaks.
t = t.replace(
    r"/\bNO_DATA_FOUND\b/i.test(t)",
    r"/\bNO_(?:DATA_FOUND|DATA_PASSED)\b/i.test(t)",
)
t = t.replace(
    r"NO_(DATA_FOUND|MESSAGE_CONTENT_HERE|API_KEY)",
    r"NO_(DATA_FOUND|DATA_PASSED|MESSAGE_CONTENT_HERE|API_KEY)",
)

# Expand explicit forbidden diagnostics/leak signatures.
t = t.replace(
    r"|| /\bNO_API_KEY\b/i.test(t);",
    r"|| /\bNO_API_KEY\b/i.test(t) || /HEARTBEAT REPORT/i.test(t) || /CRON GATEWAY DISCONNECTED/i.test(t) || /Gateway closed/i.test(t) || /\b(?:400|401|403)\s+status code\b/i.test(t) || /Configuration file:/i.test(t) || /Bind address:/i.test(t);",
)

# Strip forbidden heartbeat/http diagnostic lines from outbound text.
if "const heartbeatReportHits = countAndReplace" not in t:
    t = t.replace(
        "const invalidActionHits = countAndReplace(/does not have a valid action.*$/gmi, \"\");\n"
        "\tconst noContextMarkerHits = countAndReplace(/^\\s*NO[_ ]?(CONTEXT|CONTENT)\\b.*$/gmi, \"\");\n",
        "const invalidActionHits = countAndReplace(/does not have a valid action.*$/gmi, \"\");\n"
        "\tconst heartbeatReportHits = countAndReplace(/^\\s*HEARTBEAT REPORT\\b.*$/gmi, \"\");\n"
        "\tconst cronDisconnectedHits = countAndReplace(/^\\s*CRON GATEWAY DISCONNECTED\\b.*$/gmi, \"\");\n"
        "\tconst gatewayClosedHits = countAndReplace(/^\\s*.*Gateway closed.*$/gmi, \"\");\n"
        "\tconst httpStatusHits = countAndReplace(/^\\s*\\b(?:400|401|403)\\s+status code\\b.*$/gmi, \"\");\n"
        "\tconst cfgFileHits = countAndReplace(/^\\s*Configuration file:\\s*.*$/gmi, \"\");\n"
        "\tconst bindAddrHits = countAndReplace(/^\\s*Bind address:\\s*.*$/gmi, \"\");\n"
        "\tconst noContextMarkerHits = countAndReplace(/^\\s*NO[_ ]?(CONTEXT|CONTENT)\\b.*$/gmi, \"\");\n",
        1
    )
t = t.replace(
    "runIdHits + statusHits + errMsgHits + gwTargetHits + srcHits + bindHits + wsHits + timeoutHits + restartHits + toolValidationHits + invalidActionHits + noContextMarkerHits + noDataMarkerHits + nobellaMarkerHits + sessionArgHits + sessionFormatHits + labelFormatHits + correctedFormatHits + chooseFormatHits + sessionStatusLeakHits",
    "runIdHits + statusHits + errMsgHits + gwTargetHits + srcHits + bindHits + wsHits + timeoutHits + restartHits + toolValidationHits + invalidActionHits + heartbeatReportHits + cronDisconnectedHits + gatewayClosedHits + httpStatusHits + cfgFileHits + bindAddrHits + noContextMarkerHits + noDataMarkerHits + nobellaMarkerHits + sessionArgHits + sessionFormatHits + labelFormatHits + correctedFormatHits + chooseFormatHits + sessionStatusLeakHits"
)

# Marker for NO_DATA_PASSED suppressor update.
if "OPENCLAW_TELEGRAM_INTERNAL_MARKER_SUPPRESS_V1_0" not in t:
    t = t.replace(
        "function isTelegramInternalDiagnosticLeak(text) {",
        """/* OPENCLAW_TELEGRAM_INTERNAL_MARKER_SUPPRESS_V1_0
   Suppress marker leaks including NO_DATA_PASSED.
*/
function isTelegramInternalDiagnosticLeak(text) {""",
        1
    )

# Install a single Telegram sendMessage choke point to sanitize all outbound text send paths.
if "OPENCLAW_TELEGRAM_SENDMESSAGE_CHOKEPOINT_V1_3" not in t:
    anchor = "async function deliverReplies(params) {\n"
    insert = (
        "/* OPENCLAW_TELEGRAM_SENDMESSAGE_CHOKEPOINT_V1_3\n"
        "   Single transport choke point for all Telegram outbound text messages.\n"
        "*/\n"
        "function installTelegramSendMessageChokepoint(bot, runtime) {\n"
        "\tif (!bot?.api || typeof bot.api.sendMessage !== \"function\") return;\n"
        "\tif (bot.api.__openclawTelegramSendMessageChokepoint === true) return;\n"
        "\tconst originalSendMessage = bot.api.sendMessage.bind(bot.api);\n"
        "\tbot.api.sendMessage = async (chatId, text, params) => {\n"
        "\t\tconst chatIdStr = String(chatId ?? \"\");\n"
        "\t\tconst isGroupChat = chatIdStr.startsWith(\"-\");\n"
        "\t\tconst ownerId = String(process.env.OPENCLAW_OWNER_TELEGRAM_ID || \"TG_OWNER_ID\");\n"
        "\t\tconst debugEnabled = String(process.env.TELEGRAM_DEBUG || \"\").trim().toLowerCase();\n"
        "\t\tconst allowDiagnostics = (debugEnabled === \"1\" || debugEnabled === \"true\" || debugEnabled === \"yes\") && chatIdStr === ownerId;\n"
        "\t\tconst fallbackEnabled = [\"1\", \"true\", \"yes\"].includes(String(process.env.TELEGRAM_SAFE_FALLBACK || \"\").trim().toLowerCase());\n"
        "\t\tconst sanitized = sanitizeTelegramOutboundText(text ?? \"\", { isGroup: isGroupChat, suppressDiagnostics: !allowDiagnostics });\n"
        "\t\tlogVerbose(`[telegram-sanitize] chatId=${chatIdStr} agentId=system sanitizerApplied=${sanitized.sanitizerApplied === true ? \"true\" : \"false\"} dropped=${sanitized.dropped ? \"true\" : \"false\"} dropReason=${sanitized.dropReason} stripped=${sanitized.strippedCount} hash=${sanitized.textHash} path=chokepoint`);\n"
        "\t\tlet sanitizedText = sanitized.text;\n"
        "\t\tif (!sanitizedText) {\n"
        "\t\t\tif (fallbackEnabled && !allowDiagnostics) sanitizedText = \"Temporary issue. Try again.\";\n"
        "\t\t\telse {\n"
        "\t\t\t\truntime.log?.(`[telegram-sanitize] dropped telegram outbound at choke point chatId=${chatIdStr} dropReason=${sanitized.dropReason}`);\n"
        "\t\t\t\treturn { message_id: 0, date: Math.floor(Date.now() / 1000), chat: { id: chatId } };\n"
        "\t\t\t}\n"
        "\t\t}\n"
        "\t\tconst nextParams = { ...(params ?? {}) };\n"
        "\t\tconst usesHtml = /<\\/?[a-z][^>]*>/i.test(String(sanitizedText));\n"
        "\t\tif (!usesHtml && nextParams.parse_mode === \"HTML\") delete nextParams.parse_mode;\n"
        "\t\treturn originalSendMessage(chatId, sanitizedText, nextParams);\n"
        "\t};\n"
        "\tbot.api.__openclawTelegramSendMessageChokepoint = true;\n"
        "}\n"
    )
    if anchor in t:
        t = t.replace(anchor, insert + anchor, 1)
    else:
        raise SystemExit("deliverReplies anchor not found for choke point insertion")

# Ensure chokepoint is installed at bot startup.
if "installTelegramSendMessageChokepoint(bot, runtime);" not in t:
    t = t.replace(
        "bot.catch((err) => {\n"
        "\t\truntime.error?.(danger(`telegram bot error: ${formatUncaughtError(err)}`));\n"
        "\t});\n",
        "bot.catch((err) => {\n"
        "\t\truntime.error?.(danger(`telegram bot error: ${formatUncaughtError(err)}`));\n"
        "\t});\n"
        "\tinstallTelegramSendMessageChokepoint(bot, runtime);\n",
        1
    )

# Redact raw provider HTTP status diagnostics from lane error logs.
if "OPENCLAW_DIAG_ERROR_REDACTION_V1_0" not in t:
    t = t.replace(
        "if (!(lane.startsWith(\"auth-probe:\") || lane.startsWith(\"session:probe-\"))) diag.error(`lane task error: lane=${lane} durationMs=${Date.now() - startTime} error=\"${String(err)}\"`);",
        "if (!(lane.startsWith(\"auth-probe:\") || lane.startsWith(\"session:probe-\"))) {\n"
        "\t\t\t\t\t/* OPENCLAW_DIAG_ERROR_REDACTION_V1_0 */\n"
        "\t\t\t\t\tconst errForDiag = String(err).replace(/\\b(?:400|401|403)\\s+status code(?:\\s*\\(no body\\))?/gi, \"provider-http-error\").replace(/HEARTBEAT REPORT/gi, \"[suppressed]\").replace(/CRON GATEWAY DISCONNECTED/gi, \"[suppressed]\");\n"
        "\t\t\t\t\tdiag.error(`lane task error: lane=${lane} durationMs=${Date.now() - startTime} error=\"${errForDiag}\"`);\n"
        "\t\t\t\t}",
        1
    )

p.write_text(t)
PY

if ! rg -q "OPENCLAW_TELEGRAM_REPLY_WRAPPER_STRIP_V1_1" "${DIST_FILE}"; then
  echo "FAIL: marker missing after patch" >&2
  exit 1
fi
if ! rg -Fq 'countAndReplace(/<\/?_?reply[^>]*>/gi, "")' "${DIST_FILE}"; then
  echo "FAIL: underscore reply-wrapper strip logic missing after patch" >&2
  exit 1
fi
if ! rg -Fq 'wrappedReplyMatch = t.match(/^\s*<_?reply[^>]*>([\s\S]*?)<\/_?reply>\s*$/i);' "${DIST_FILE}"; then
  echo "FAIL: wrapped reply pattern missing after patch" >&2
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_TEXTMODE_EMOJI_V1_0" "${DIST_FILE}"; then
  echo "FAIL: emoji textmode marker missing after patch" >&2
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_1" "${DIST_FILE}"; then
  echo "FAIL: Amharic enforcement marker missing after patch" >&2
  exit 1
fi
if ! rg -q "looksPlaceholder = /\\^\\\\s\\*\\\\\\[AMHARIC TRANSLATION OF:/i" "${DIST_FILE}"; then
  echo "FAIL: placeholder guard missing after patch" >&2
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_INTERNAL_MARKER_SUPPRESS_V1_0" "${DIST_FILE}"; then
  echo "FAIL: NO_DATA_PASSED suppressor marker missing after patch" >&2
  exit 1
fi
if ! rg -q "NO_\\(DATA_FOUND\\|DATA_PASSED\\|MESSAGE_CONTENT_HERE\\|API_KEY\\)" "${DIST_FILE}"; then
  echo "FAIL: NO_DATA_PASSED suppressor pattern missing after patch" >&2
  exit 1
fi
if ! rg -q "OPENCLAW_TELEGRAM_SENDMESSAGE_CHOKEPOINT_V1_3" "${DIST_FILE}"; then
  echo "FAIL: sendMessage chokepoint marker missing after patch" >&2
  exit 1
fi
if ! rg -q "path=chokepoint" "${DIST_FILE}"; then
  echo "FAIL: sendMessage chokepoint telemetry missing after patch" >&2
  exit 1
fi
if ! rg -q "OPENCLAW_DIAG_ERROR_REDACTION_V1_0" "${DIST_FILE}"; then
  echo "FAIL: diagnostic error redaction marker missing after patch" >&2
  exit 1
fi

echo "PASS: telegram runtime patches applied"
