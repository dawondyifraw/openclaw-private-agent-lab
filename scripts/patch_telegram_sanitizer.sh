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
  && rg -q "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_0" "${DIST_FILE}"; then
  echo "PASS: reply-wrapper + emoji textmode + Amharic enforcement patches already present"
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
if "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_0" not in t:
    old_block = (
        "const sanitized = sanitizeTelegramOutboundText(reply?.text ?? \"\", { isGroup: isGroupChat, suppressDiagnostics: !allowDiagnostics });\n"
        "\t\tconst sanitizedText = sanitized.text;\n"
        "\t\tconst replyToId = replyToMode === \"off\" ? void 0 : resolveTelegramReplyId(reply.replyToId);\n"
    )
    new_block = (
        "const sanitized = sanitizeTelegramOutboundText(reply?.text ?? \"\", { isGroup: isGroupChat, suppressDiagnostics: !allowDiagnostics });\n"
        "\t\tlet sanitizedText = sanitized.text;\n"
        "\t\t/* OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_0\n"
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
        "\t\t\t\tif (translated) sanitizedText = translated;\n"
        "\t\t\t\telse sanitizedText = \"እባክዎ መልእክትዎን በአማርኛ ይጻፉ።\";\n"
        "\t\t\t} else sanitizedText = \"እባክዎ መልእክትዎን በአማርኛ ይጻፉ።\";\n"
        "\t\t} catch {\n"
        "\t\t\tsanitizedText = \"እባክዎ መልእክትዎን በአማርኛ ይጻፉ።\";\n"
        "\t\t}\n"
        "\t\tconst replyToId = replyToMode === \"off\" ? void 0 : resolveTelegramReplyId(reply.replyToId);\n"
    )
    if old_block in t:
        t = t.replace(old_block, new_block, 1)
    else:
        raise SystemExit("deliverReplies sanitizedText block not found for Amharic enforcement patch")

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
if ! rg -q "OPENCLAW_TELEGRAM_AMHARIC_ENFORCEMENT_V1_0" "${DIST_FILE}"; then
  echo "FAIL: Amharic enforcement marker missing after patch" >&2
  exit 1
fi

echo "PASS: reply-wrapper + emoji textmode + Amharic enforcement patches applied"
