# Telegram Leak Harvest Report

- Generated: 2026-02-11T14:17:32.864690Z
- Window: last 2 hour(s) (since 2026-02-11 13:17:32)
- Total candidate hits: 86

## Pattern Counts
| Source:Pattern | Count |
|---|---:|
| `session:http_status_400_401_403` | 44 |
| `journal:http_status_400_401_403` | 20 |
| `session:no_reply_wrapper` | 12 |
| `session:reply_wrapper` | 8 |
| `session:novelty_marker` | 1 |
| `session:searchweb_wrapper` | 1 |

## Journal Samples
```text
1: 2026-02-11T12:25:39.610Z [diagnostic] lane task error: lane=main durationMs=1011 error="FailoverError: 400 status code (no body)"
2: 2026-02-11T12:25:39.611Z [diagnostic] lane task error: lane=session:agent:anxietychat:telegram:group:TG_GROUP_ANXIETY_CHAT_ID durationMs=1013 error="FailoverError: 400 status code (no body)"
412: 2026-02-11T12:26:44.981Z [diagnostic] lane task error: lane=main durationMs=1113 error="FailoverError: 400 status code (no body)"
413: 2026-02-11T12:26:44.982Z [diagnostic] lane task error: lane=session:agent:main:main durationMs=1116 error="FailoverError: 400 status code (no body)"
641: 2026-02-11T12:32:41.598Z [diagnostic] lane task error: lane=main durationMs=3566 error="FailoverError: 400 status code (no body)"
642: 2026-02-11T12:32:41.598Z [diagnostic] lane task error: lane=session:agent:main:main durationMs=3568 error="FailoverError: 400 status code (no body)"
702: 2026-02-11T12:37:20.458Z [diagnostic] lane task error: lane=main durationMs=750 error="FailoverError: 400 status code (no body)"
703: 2026-02-11T12:37:20.459Z [diagnostic] lane task error: lane=session:agent:main:main durationMs=752 error="FailoverError: 400 status code (no body)"
1404: 2026-02-11T12:46:32.554Z [diagnostic] lane task error: lane=main durationMs=3621 error="FailoverError: 400 status code (no body)"
1405: 2026-02-11T12:46:32.554Z [diagnostic] lane task error: lane=session:agent:merry-bot:telegram:group:TG_GROUP_MERRY_ID durationMs=3624 error="FailoverError: 400 status code (no body)"
1462: 2026-02-11T12:48:51.818Z [diagnostic] lane task error: lane=main durationMs=607 error="FailoverError: 400 status code (no body)"
1463: 2026-02-11T12:48:51.819Z [diagnostic] lane task error: lane=session:agent:merry-bot:telegram:group:TG_GROUP_MERRY_ID durationMs=610 error="FailoverError: 400 status code (no body)"
1464: 2026-02-11T12:49:12.276Z [diagnostic] lane task error: lane=main durationMs=953 error="FailoverError: 400 status code (no body)"
1465: 2026-02-11T12:49:12.277Z [diagnostic] lane task error: lane=session:agent:assistant:telegram:group:TG_GROUP_ASSISTANT_DASHBOARD_ID durationMs=955 error="FailoverError: 400 status code (no body)"
1525: 2026-02-11T12:50:06.741Z [diagnostic] lane task error: lane=main durationMs=1052 error="FailoverError: 400 status code (no body)"
1526: 2026-02-11T12:50:06.742Z [diagnostic] lane task error: lane=session:agent:g-coder:telegram:group:TG_GROUP_CODER_ID durationMs=1054 error="FailoverError: 400 status code (no body)"
1527: 2026-02-11T12:50:07.074Z [diagnostic] lane task error: lane=main durationMs=1074 error="FailoverError: 400 status code (no body)"
1528: 2026-02-11T12:50:07.075Z [diagnostic] lane task error: lane=session:agent:main:main durationMs=1076 error="FailoverError: 400 status code (no body)"
1529: 2026-02-11T12:50:08.460Z [diagnostic] lane task error: lane=main durationMs=584 error="FailoverError: 400 status code (no body)"
1530: 2026-02-11T12:50:08.461Z [diagnostic] lane task error: lane=session:agent:anxietychat:telegram:group:TG_GROUP_ANXIETY_CHAT_ID durationMs=586 error="FailoverError: 400 status code (no body)"
```

## Session Samples
```text
/home/devbox/.openclaw/agents/anxietychat/sessions/2e28fb00-8c94-4b5e-a6a7-39112af7908d.jsonl:90: [Telegram AnxityChat id:TG_GROUP_ANXIETY_CHAT_ID +37m Wed 2026-02-11 13:25 GMT+1] zim (TG_OWNER_ID): sadasdEnable emoji style only for conversational agents (main, merry, hello) with a bounded rule: “Use emojis sparingly and contextually (0–2 per reply).” Add/keep sanitizer that strips wrapper artifacts like <reply>...</reply> before sending to Telegram. [message_id: 372]
/home/devbox/.openclaw/agents/anxietychat/sessions/2e28fb00-8c94-4b5e-a6a7-39112af7908d.jsonl:91: 400 status code (no body)
/home/devbox/.openclaw/agents/anxietychat/sessions/2e28fb00-8c94-4b5e-a6a7-39112af7908d.jsonl:93: [Telegram AnxityChat id:TG_GROUP_ANXIETY_CHAT_ID +37m Wed 2026-02-11 13:25 GMT+1] zim (TG_OWNER_ID): sadasdEnable emoji style only for conversational agents (main, merry, hello) with a bounded rule: “Use emojis sparingly and contextually (0–2 per reply).” Add/keep sanitizer that strips wrapper artifacts like <reply>...</reply> before sending to Telegram. [message_id: 372]
/home/devbox/.openclaw/agents/anxietychat/sessions/2e28fb00-8c94-4b5e-a6a7-39112af7908d.jsonl:97: 400 status code (no body)
/home/devbox/.openclaw/agents/anxietychat/sessions/2e28fb00-8c94-4b5e-a6a7-39112af7908d.jsonl:99: 400 status code (no body)
/home/devbox/.openclaw/agents/anxietychat/sessions/2e28fb00-8c94-4b5e-a6a7-39112af7908d.jsonl:101: 400 status code (no body)
/home/devbox/.openclaw/agents/assistant/sessions/416761ad-f7c6-4b9d-85fb-902f93129309.jsonl:44: 400 status code (no body)
/home/devbox/.openclaw/agents/assistant/sessions/416761ad-f7c6-4b9d-85fb-902f93129309.jsonl:53: <NO_REPLY>
/home/devbox/.openclaw/agents/assistant/sessions/416761ad-f7c6-4b9d-85fb-902f93129309.jsonl:55: <NO_REPLY>
/home/devbox/.openclaw/agents/assistant/sessions/416761ad-f7c6-4b9d-85fb-902f93129309.jsonl:57: <NO_REPLY>No content to respond to, as the message received was a single character "ስ" which lacks context or a clear request for information/action. Remaining silent respects Telegram's noise reduction and communication clarity principles.</NO_REPLY>
/home/devbox/.openclaw/agents/assistant/sessions/416761ad-f7c6-4b9d-85fb-902f93129309.jsonl:71: <NO_REPLY>
/home/devbox/.openclaw/agents/assistant/sessions/416761ad-f7c6-4b9d-85fb-902f93129309.jsonl:73: <NO_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:102: [Telegram የሜሪሮቦት id:TG_GROUP_MERRY_ID +9m Wed 2026-02-11 13:24 GMT+1] zim (TG_OWNER_ID): i mn fine hgow arew toy [Replying to ጥበቡ👾AI id:532] <reply> Hello! How can I assist you today? </reply> [/Replying] [message_id: 533]
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:103: <reply> It seems like there was a typo in your message. Did you mean to ask "How are you?" or were you trying to ask something else? I'm here to help, so feel free to clarify! </reply>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:105: <searchWeb>(query="latest news")</searchWeb>(NO_REPLY)
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:106: [Telegram የሜሪሮቦት id:TG_GROUP_MERRY_ID +24s Wed 2026-02-11 13:25 GMT+1] zim (TG_OWNER_ID): Enable emoji style only for conversational agents (main, merry, hello) with a bounded rule: “Use emojis sparingly and contextually (0–2 per reply).” Add/keep sanitizer that strips wrapper artifacts like <reply>...</reply> before sending to Telegram. [message_id: 536]
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:108: <_REPLY> Hey! How can I assist you today? 😊 <_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:109: [Telegram የሜሪሮቦት id:TG_GROUP_MERRY_ID +2m Wed 2026-02-11 13:28 GMT+1] zim (TG_OWNER_ID): Enable emoji style only for conversational agents (main, merry, hello) with a bounded rule: “Use emojis sparingly and contextually (0–2 per reply).” Add/keep sanitizer that strips wrapper artifacts like <reply>...</reply> before sending to Telegram. [message_id: 539]
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:118: <NO_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:133: <reply> Hi there! How can I assist you today? </reply>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:138: 400 status code (no body)
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:140: 400 status code (no body)
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:142: 400 status code (no body)
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:148: 400 status code (no body)
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:150: 400 status code (no body)
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:152: 400 status code (no body)
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:155: <NO_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:159: <NO_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:161: <NO_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:167: <NO_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:169: <NO_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:173: <NO_REPLY>
/home/devbox/.openclaw/agents/merry-bot/sessions/f74a9e33-166d-47a1-a718-8a27c7b18d07.jsonl:176: 400 status code (no body)
/home/devbox/.openclaw/agents/g-coder/sessions/f80651d3-4e15-4b6b-a419-ace89b7fad23.jsonl:41: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:170: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:187: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:189: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:191: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:201: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:203: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:205: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:217: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:219: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:221: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:244: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:246: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:248: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:276: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:278: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:280: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:286: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:288: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:290: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:295: NOVELTY: The message "fsd" seems to be a placeholder or an incomplete command, possibly meant for testing or eliciting further user input in a conversational flow. Given this minimal context and the apparent lack of meaningful communication here, there's no specific action required from me beyond seeking clarification.  To proceed, I'll ask for additional details rather than making assumptions about what is intended:  Could you please provide more information or clarify your request? Were you testing something or looking for assistance with a particular task?
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:314: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:316: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:318: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:334: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:336: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:338: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:356: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:358: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:360: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:374: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:376: 400 status code (no body)
/home/devbox/.openclaw/agents/main/sessions/b71f13c3-da89-42df-a08b-8f51d76e616d.jsonl:378: 400 status code (no body)
```

## Suggested Follow-ups
- Add any new signature here into `tests/data/telegram_model_fuzz_cases.json` with `expect=drop`.
- Re-run strict suite: `OPENCLAW_TEST_MODE=strict bash tests/run_all_tests.sh`.
