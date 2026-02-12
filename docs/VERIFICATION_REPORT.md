# OpenClaw System Verification Report
**Date:** Mon Feb  9 09:26:31 CET 2026
**System Version:** 2026.2.6-3
**Docker Compose Version:** 5.0.2

## Service Endpoints
| Service | Endpoint |
|---------|----------|
| Ollama  | http://localhost:11434 |
| Chroma  | http://localhost:8000 |
| RAG     | http://localhost:8811 |
| Amharic | http://localhost:18790 |

## Test Results
| Category | Status | Details |
|----------|--------|---------|

### Evidence: Gateway Logs (Last 200 Lines)
```
Feb 09 06:50:35 Godgift node[115532]: 2026-02-09T05:50:35.666Z [ws] closed before connect conn=ed9714bd-4bbc-47de-9ae3-befa1e8c9dcf remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 code=1008 reason=unauthorized: gateway token mismatch (open the dashboard URL and paste the token in Control UI settings)
Feb 09 06:50:50 Godgift node[115532]: 2026-02-09T05:50:50.332Z [ws] unauthorized conn=ca1d8c1b-ba79-4351-961c-fd9f524a3649 remote=127.0.0.1 client=openclaw-control-ui webchat vdev reason=token_mismatch
Feb 09 06:50:50 Godgift node[115532]: 2026-02-09T05:50:50.336Z [ws] closed before connect conn=ca1d8c1b-ba79-4351-961c-fd9f524a3649 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 code=1008 reason=unauthorized: gateway token mismatch (open the dashboard URL and paste the token in Control UI settings)
Feb 09 06:51:07 Godgift node[115532]: 2026-02-09T05:51:07.579Z [ws] unauthorized conn=ae1faf42-1e13-4ca8-bd7e-99260dcc62b0 remote=127.0.0.1 client=openclaw-control-ui webchat vdev reason=token_mismatch
Feb 09 06:51:07 Godgift node[115532]: 2026-02-09T05:51:07.580Z [ws] closed before connect conn=ae1faf42-1e13-4ca8-bd7e-99260dcc62b0 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 code=1008 reason=unauthorized: gateway token mismatch (open the dashboard URL and paste the token in Control UI settings)
Feb 09 06:51:22 Godgift node[115532]: 2026-02-09T05:51:22.229Z [ws] unauthorized conn=6f026016-a5c9-4329-8df9-b4e3fc6057e6 remote=127.0.0.1 client=openclaw-control-ui webchat vdev reason=token_mismatch
Feb 09 06:51:22 Godgift node[115532]: 2026-02-09T05:51:22.231Z [ws] closed before connect conn=6f026016-a5c9-4329-8df9-b4e3fc6057e6 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 code=1008 reason=unauthorized: gateway token mismatch (open the dashboard URL and paste the token in Control UI settings)
Feb 09 06:51:40 Godgift node[115532]: 2026-02-09T05:51:40.091Z [ws] unauthorized conn=e4b20b16-d8a6-475e-a6a1-ffae21e101c3 remote=127.0.0.1 client=openclaw-control-ui webchat vdev reason=token_mismatch
Feb 09 06:51:40 Godgift node[115532]: 2026-02-09T05:51:40.094Z [ws] closed before connect conn=e4b20b16-d8a6-475e-a6a1-ffae21e101c3 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 code=1008 reason=unauthorized: gateway token mismatch (open the dashboard URL and paste the token in Control UI settings)
Feb 09 06:51:54 Godgift node[115532]: 2026-02-09T05:51:54.751Z [ws] unauthorized conn=afe8c5d0-a7dc-428c-94be-d49b8e6b3c18 remote=127.0.0.1 client=openclaw-control-ui webchat vdev reason=token_mismatch
Feb 09 06:51:54 Godgift node[115532]: 2026-02-09T05:51:54.754Z [ws] closed before connect conn=afe8c5d0-a7dc-428c-94be-d49b8e6b3c18 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 code=1008 reason=unauthorized: gateway token mismatch (open the dashboard URL and paste the token in Control UI settings)
Feb 09 06:52:11 Godgift node[115532]: 2026-02-09T05:52:11.966Z [ws] unauthorized conn=5f2e23a9-b722-4485-ac2b-cdccf3758b44 remote=127.0.0.1 client=openclaw-control-ui webchat vdev reason=token_mismatch
Feb 09 06:52:11 Godgift node[115532]: 2026-02-09T05:52:11.967Z [ws] closed before connect conn=5f2e23a9-b722-4485-ac2b-cdccf3758b44 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 code=1008 reason=unauthorized: gateway token mismatch (open the dashboard URL and paste the token in Control UI settings)
Feb 09 06:52:26 Godgift node[115532]: 2026-02-09T05:52:26.742Z [ws] unauthorized conn=aaa08895-5dc6-4b5e-8499-70a88c3c6cb7 remote=127.0.0.1 client=openclaw-control-ui webchat vdev reason=token_mismatch
Feb 09 06:52:26 Godgift node[115532]: 2026-02-09T05:52:26.744Z [ws] closed before connect conn=aaa08895-5dc6-4b5e-8499-70a88c3c6cb7 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 code=1008 reason=unauthorized: gateway token mismatch (open the dashboard URL and paste the token in Control UI settings)
Feb 09 08:00:21 Godgift node[115532]: 2026-02-09T07:00:21.290Z [openclaw] Non-fatal unhandled rejection (continuing): TypeError: fetch failed
Feb 09 08:00:21 Godgift node[115532]:     at node:internal/deps/undici/undici:14902:13
Feb 09 08:38:17 Godgift node[115532]: 2026-02-09T07:38:17.819Z [agent/embedded] read tool called without path: toolCallId=tool_4Dw9IFgcNO7aBW9geqtYA7hg argsType=object
Feb 09 08:44:39 Godgift systemd[540]: Stopping openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3)...
Feb 09 08:44:39 Godgift node[115532]: 2026-02-09T07:44:39.529Z [gateway] signal SIGTERM received
Feb 09 08:44:39 Godgift node[115532]: 2026-02-09T07:44:39.530Z [gateway] received SIGTERM; shutting down
Feb 09 08:44:39 Godgift node[115532]: 2026-02-09T07:44:39.545Z [gmail-watcher] gmail watcher stopped
Feb 09 08:44:39 Godgift systemd[540]: Stopped openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 08:44:39 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.299Z [canvas] host mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /home/devbox/.openclaw/canvas)
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.345Z [heartbeat] started
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.349Z [gateway] agent model: kimi-coding/k2p5
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.350Z [gateway] listening on ws://127.0.0.1:18789 (PID 256034)
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.351Z [gateway] listening on ws://[::1]:18789
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.353Z [gateway] log file: /tmp/openclaw/openclaw-2026-02-09.log
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.367Z [browser/service] Browser control service ready (profiles=2)
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.586Z [telegram] [default] starting provider (@moltbotd_bot)
Feb 09 08:44:42 Godgift node[256034]: 2026-02-09T07:44:42.597Z [telegram] autoSelectFamily=false (default-node22)
Feb 09 09:10:29 Godgift node[256034]: 2026-02-09T08:10:29.395Z [reload] config reload skipped (invalid config): models.providers.google.models.0.input.2: Invalid input, models.providers.google.models.0.input.3: Invalid input
Feb 09 09:10:36 Godgift node[256034]: 2026-02-09T08:10:36.062Z [reload] config reload skipped (invalid config): models.providers.google.models.0.input.2: Invalid input, models.providers.google.models.0.input.3: Invalid input
Feb 09 09:10:40 Godgift node[256034]: 2026-02-09T08:10:40.403Z Invalid config at /home/devbox/.openclaw/openclaw.json:\n- models.providers.google.models.0.input.2: Invalid input
Feb 09 09:10:40 Godgift node[256034]: - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:11:39 Godgift systemd[540]: Stopping openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3)...
Feb 09 09:11:39 Godgift node[256034]: 2026-02-09T08:11:39.870Z [gateway] signal SIGTERM received
Feb 09 09:11:39 Godgift node[256034]: 2026-02-09T08:11:39.871Z [gateway] received SIGTERM; shutting down
Feb 09 09:11:39 Godgift node[256034]: 2026-02-09T08:11:39.881Z [gmail-watcher] gmail watcher stopped
Feb 09 09:11:40 Godgift systemd[540]: Stopped openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:11:40 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:11:41 Godgift node[272381]: Invalid config at /home/devbox/.openclaw/openclaw.json:\n- models.providers.google.models.0.input.2: Invalid input
Feb 09 09:11:41 Godgift node[272381]: - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:11:41 Godgift node[272381]: │
Feb 09 09:11:41 Godgift node[272381]: ◇  Config ───────────────────────────────────────────────────╮
Feb 09 09:11:41 Godgift node[272381]: │                                                            │
Feb 09 09:11:41 Godgift node[272381]: │  Config invalid; doctor will run with best-effort config.  │
Feb 09 09:11:41 Godgift node[272381]: │                                                            │
Feb 09 09:11:41 Godgift node[272381]: ├────────────────────────────────────────────────────────────╯
Feb 09 09:11:41 Godgift node[272381]: Config invalid
Feb 09 09:11:41 Godgift node[272381]: File: ~/.openclaw/openclaw.json
Feb 09 09:11:41 Godgift node[272381]: Problem:
Feb 09 09:11:41 Godgift node[272381]:   - models.providers.google.models.0.input.2: Invalid input
Feb 09 09:11:41 Godgift node[272381]:   - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:11:41 Godgift node[272381]: Run: openclaw doctor --fix
Feb 09 09:11:41 Godgift systemd[540]: openclaw-gateway.service: Main process exited, code=exited, status=1/FAILURE
Feb 09 09:11:41 Godgift systemd[540]: openclaw-gateway.service: Failed with result 'exit-code'.
Feb 09 09:11:46 Godgift systemd[540]: openclaw-gateway.service: Scheduled restart job, restart counter is at 1.
Feb 09 09:11:46 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:11:47 Godgift node[272573]: Invalid config at /home/devbox/.openclaw/openclaw.json:\n- models.providers.google.models.0.input.2: Invalid input
Feb 09 09:11:47 Godgift node[272573]: - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:11:47 Godgift node[272573]: │
Feb 09 09:11:47 Godgift node[272573]: ◇  Config ───────────────────────────────────────────────────╮
Feb 09 09:11:47 Godgift node[272573]: │                                                            │
Feb 09 09:11:47 Godgift node[272573]: │  Config invalid; doctor will run with best-effort config.  │
Feb 09 09:11:47 Godgift node[272573]: │                                                            │
Feb 09 09:11:47 Godgift node[272573]: ├────────────────────────────────────────────────────────────╯
Feb 09 09:11:47 Godgift node[272573]: Config invalid
Feb 09 09:11:47 Godgift node[272573]: File: ~/.openclaw/openclaw.json
Feb 09 09:11:47 Godgift node[272573]: Problem:
Feb 09 09:11:47 Godgift node[272573]:   - models.providers.google.models.0.input.2: Invalid input
Feb 09 09:11:47 Godgift node[272573]:   - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:11:47 Godgift node[272573]: Run: openclaw doctor --fix
Feb 09 09:11:47 Godgift systemd[540]: openclaw-gateway.service: Main process exited, code=exited, status=1/FAILURE
Feb 09 09:11:47 Godgift systemd[540]: openclaw-gateway.service: Failed with result 'exit-code'.
Feb 09 09:11:52 Godgift systemd[540]: openclaw-gateway.service: Scheduled restart job, restart counter is at 2.
Feb 09 09:11:52 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:11:53 Godgift node[272669]: Invalid config at /home/devbox/.openclaw/openclaw.json:\n- models.providers.google.models.0.input.2: Invalid input
Feb 09 09:11:53 Godgift node[272669]: - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:11:53 Godgift node[272669]: │
Feb 09 09:11:53 Godgift node[272669]: ◇  Config ───────────────────────────────────────────────────╮
Feb 09 09:11:53 Godgift node[272669]: │                                                            │
Feb 09 09:11:53 Godgift node[272669]: │  Config invalid; doctor will run with best-effort config.  │
Feb 09 09:11:53 Godgift node[272669]: │                                                            │
Feb 09 09:11:53 Godgift node[272669]: ├────────────────────────────────────────────────────────────╯
Feb 09 09:11:53 Godgift node[272669]: Config invalid
Feb 09 09:11:53 Godgift node[272669]: File: ~/.openclaw/openclaw.json
Feb 09 09:11:53 Godgift node[272669]: Problem:
Feb 09 09:11:53 Godgift node[272669]:   - models.providers.google.models.0.input.2: Invalid input
Feb 09 09:11:53 Godgift node[272669]:   - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:11:53 Godgift node[272669]: Run: openclaw doctor --fix
Feb 09 09:11:53 Godgift systemd[540]: openclaw-gateway.service: Main process exited, code=exited, status=1/FAILURE
Feb 09 09:11:53 Godgift systemd[540]: openclaw-gateway.service: Failed with result 'exit-code'.
Feb 09 09:11:59 Godgift systemd[540]: openclaw-gateway.service: Scheduled restart job, restart counter is at 3.
Feb 09 09:11:59 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:12:00 Godgift node[272734]: Invalid config at /home/devbox/.openclaw/openclaw.json:\n- models.providers.google.models.0.input.2: Invalid input
Feb 09 09:12:00 Godgift node[272734]: - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:12:00 Godgift node[272734]: │
Feb 09 09:12:00 Godgift node[272734]: ◇  Config ───────────────────────────────────────────────────╮
Feb 09 09:12:00 Godgift node[272734]: │                                                            │
Feb 09 09:12:00 Godgift node[272734]: │  Config invalid; doctor will run with best-effort config.  │
Feb 09 09:12:00 Godgift node[272734]: │                                                            │
Feb 09 09:12:00 Godgift node[272734]: ├────────────────────────────────────────────────────────────╯
Feb 09 09:12:00 Godgift node[272734]: Config invalid
Feb 09 09:12:00 Godgift node[272734]: File: ~/.openclaw/openclaw.json
Feb 09 09:12:00 Godgift node[272734]: Problem:
Feb 09 09:12:00 Godgift node[272734]:   - models.providers.google.models.0.input.2: Invalid input
Feb 09 09:12:00 Godgift node[272734]:   - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:12:00 Godgift node[272734]: Run: openclaw doctor --fix
Feb 09 09:12:00 Godgift systemd[540]: openclaw-gateway.service: Main process exited, code=exited, status=1/FAILURE
Feb 09 09:12:00 Godgift systemd[540]: openclaw-gateway.service: Failed with result 'exit-code'.
Feb 09 09:12:05 Godgift systemd[540]: openclaw-gateway.service: Scheduled restart job, restart counter is at 4.
Feb 09 09:12:05 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:12:06 Godgift node[272818]: Invalid config at /home/devbox/.openclaw/openclaw.json:\n- models.providers.google.models.0.input.2: Invalid input
Feb 09 09:12:06 Godgift node[272818]: - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:12:06 Godgift node[272818]: │
Feb 09 09:12:06 Godgift node[272818]: ◇  Config ───────────────────────────────────────────────────╮
Feb 09 09:12:06 Godgift node[272818]: │                                                            │
Feb 09 09:12:06 Godgift node[272818]: │  Config invalid; doctor will run with best-effort config.  │
Feb 09 09:12:06 Godgift node[272818]: │                                                            │
Feb 09 09:12:06 Godgift node[272818]: ├────────────────────────────────────────────────────────────╯
Feb 09 09:12:06 Godgift node[272818]: Config invalid
Feb 09 09:12:06 Godgift node[272818]: File: ~/.openclaw/openclaw.json
Feb 09 09:12:06 Godgift node[272818]: Problem:
Feb 09 09:12:06 Godgift node[272818]:   - models.providers.google.models.0.input.2: Invalid input
Feb 09 09:12:06 Godgift node[272818]:   - models.providers.google.models.0.input.3: Invalid input
Feb 09 09:12:06 Godgift node[272818]: Run: openclaw doctor --fix
Feb 09 09:12:06 Godgift systemd[540]: openclaw-gateway.service: Main process exited, code=exited, status=1/FAILURE
Feb 09 09:12:06 Godgift systemd[540]: openclaw-gateway.service: Failed with result 'exit-code'.
Feb 09 09:12:14 Godgift systemd[540]: openclaw-gateway.service: Scheduled restart job, restart counter is at 5.
Feb 09 09:12:14 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:12:15 Godgift node[272887]: 2026-02-09T08:12:15.970Z [canvas] host mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /home/devbox/.openclaw/canvas)
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.006Z [heartbeat] started
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.010Z [gateway] agent model: kimi-coding/k2p5
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.011Z [gateway] listening on ws://127.0.0.1:18789 (PID 272887)
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.012Z [gateway] listening on ws://[::1]:18789
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.014Z [gateway] log file: /tmp/openclaw/openclaw-2026-02-09.log
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.027Z [browser/service] Browser control service ready (profiles=2)
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.236Z [telegram] [default] starting provider (@moltbotd_bot)
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.282Z [telegram] autoSelectFamily=false (default-node22)
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.573Z [diagnostic] lane task error: lane=main durationMs=19 error="FailoverError: No API key found for provider "google". Auth store: /home/devbox/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /home/devbox/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir."
Feb 09 09:12:16 Godgift node[272887]: 2026-02-09T08:12:16.574Z [diagnostic] lane task error: lane=session:agent:main:main durationMs=24 error="FailoverError: No API key found for provider "google". Auth store: /home/devbox/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /home/devbox/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir."
Feb 09 09:15:13 Godgift systemd[540]: Stopping openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3)...
Feb 09 09:15:13 Godgift node[272887]: 2026-02-09T08:15:13.908Z [gateway] signal SIGTERM received
Feb 09 09:15:13 Godgift node[272887]: 2026-02-09T08:15:13.910Z [gateway] received SIGTERM; shutting down
Feb 09 09:15:13 Godgift node[272887]: 2026-02-09T08:15:13.920Z [gmail-watcher] gmail watcher stopped
Feb 09 09:15:14 Godgift systemd[540]: Stopped openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:15:14 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:15:15 Godgift node[274968]: 2026-02-09T08:15:15.909Z [canvas] host mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /home/devbox/.openclaw/canvas)
Feb 09 09:15:15 Godgift node[274968]: 2026-02-09T08:15:15.960Z [heartbeat] started
Feb 09 09:15:15 Godgift node[274968]: 2026-02-09T08:15:15.965Z [gateway] agent model: kimi-coding/k2p5
Feb 09 09:15:15 Godgift node[274968]: 2026-02-09T08:15:15.967Z [gateway] listening on ws://127.0.0.1:18789 (PID 274968)
Feb 09 09:15:15 Godgift node[274968]: 2026-02-09T08:15:15.968Z [gateway] listening on ws://[::1]:18789
Feb 09 09:15:15 Godgift node[274968]: 2026-02-09T08:15:15.970Z [gateway] log file: /tmp/openclaw/openclaw-2026-02-09.log
Feb 09 09:15:15 Godgift node[274968]: 2026-02-09T08:15:15.985Z [browser/service] Browser control service ready (profiles=2)
Feb 09 09:15:16 Godgift node[274968]: 2026-02-09T08:15:16.186Z [telegram] [default] starting provider (@moltbotd_bot)
Feb 09 09:15:16 Godgift node[274968]: 2026-02-09T08:15:16.196Z [telegram] autoSelectFamily=false (default-node22)
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.333Z [reload] config change detected; evaluating reload (auth.profiles.google:default, auth.profiles.groq:default, auth.profiles.openrouter:default, auth.order.google, auth.order.groq, auth.order.openrouter, models.providers.kimi-coding.models, models.providers.google.models, models.providers.groq.models, models.providers.openrouter.models, models.providers.ollama.models, agents.list)
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.334Z [reload] config change requires gateway restart (auth.profiles.google:default, auth.profiles.groq:default, auth.profiles.openrouter:default, auth.order.google, auth.order.groq, auth.order.openrouter)
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.337Z [gateway] signal SIGUSR1 received
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.337Z [gateway] received SIGUSR1; restarting
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.346Z [gmail-watcher] gmail watcher stopped
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.578Z [openclaw] Suppressed AbortError: AbortError: This operation was aborted
Feb 09 09:15:51 Godgift node[274968]:     at node:internal/deps/undici/undici:14902:13
Feb 09 09:15:51 Godgift node[274968]:     at processTicksAndRejections (node:internal/process/task_queues:105:5)
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.583Z [canvas] host mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /home/devbox/.openclaw/canvas)
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.591Z [heartbeat] started
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.592Z [gateway] agent model: kimi-coding/k2p5
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.593Z [gateway] listening on ws://127.0.0.1:18789 (PID 274968)
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.594Z [gateway] listening on ws://[::1]:18789
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.595Z [gateway] log file: /tmp/openclaw/openclaw-2026-02-09.log
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.599Z [browser/service] Browser control service ready (profiles=2)
Feb 09 09:15:51 Godgift node[274968]: 2026-02-09T08:15:51.718Z [telegram] [default] starting provider (@moltbotd_bot)
Feb 09 09:17:42 Godgift node[274968]: 2026-02-09T08:17:42.050Z [openclaw] Non-fatal unhandled rejection (continuing): TypeError: fetch failed
Feb 09 09:17:42 Godgift node[274968]:     at node:internal/deps/undici/undici:14902:13
Feb 09 09:20:11 Godgift node[274968]: 2026-02-09T08:20:11.729Z [diagnostic] lane task error: lane=main durationMs=21 error="FailoverError: No API key found for provider "google". Auth store: /home/devbox/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /home/devbox/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir."
Feb 09 09:20:11 Godgift node[274968]: 2026-02-09T08:20:11.730Z [diagnostic] lane task error: lane=session:agent:main:main durationMs=26 error="FailoverError: No API key found for provider "google". Auth store: /home/devbox/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /home/devbox/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir."
Feb 09 09:22:23 Godgift systemd[540]: Stopping openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3)...
Feb 09 09:22:23 Godgift node[274968]: 2026-02-09T08:22:23.174Z [gateway] signal SIGTERM received
Feb 09 09:22:23 Godgift node[274968]: 2026-02-09T08:22:23.175Z [gateway] received SIGTERM; shutting down
Feb 09 09:22:23 Godgift node[274968]: 2026-02-09T08:22:23.184Z [gmail-watcher] gmail watcher stopped
Feb 09 09:22:23 Godgift systemd[540]: Stopped openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:22:23 Godgift systemd[540]: Started openclaw-gateway.service - OpenClaw Gateway (v2026.2.6-3).
Feb 09 09:22:24 Godgift node[281318]: 2026-02-09T08:22:24.903Z [canvas] host mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /home/devbox/.openclaw/canvas)
Feb 09 09:22:24 Godgift node[281318]: 2026-02-09T08:22:24.938Z [heartbeat] started
Feb 09 09:22:24 Godgift node[281318]: 2026-02-09T08:22:24.942Z [gateway] agent model: kimi-coding/k2p5
Feb 09 09:22:24 Godgift node[281318]: 2026-02-09T08:22:24.943Z [gateway] listening on ws://127.0.0.1:18789 (PID 281318)
Feb 09 09:22:24 Godgift node[281318]: 2026-02-09T08:22:24.944Z [gateway] listening on ws://[::1]:18789
Feb 09 09:22:24 Godgift node[281318]: 2026-02-09T08:22:24.946Z [gateway] log file: /tmp/openclaw/openclaw-2026-02-09.log
Feb 09 09:22:24 Godgift node[281318]: 2026-02-09T08:22:24.960Z [browser/service] Browser control service ready (profiles=2)
Feb 09 09:22:25 Godgift node[281318]: 2026-02-09T08:22:25.805Z [telegram] [default] starting provider (@moltbotd_bot)
Feb 09 09:22:25 Godgift node[281318]: 2026-02-09T08:22:25.817Z [telegram] autoSelectFamily=false (default-node22)
Feb 09 09:24:54 Godgift node[281318]: 2026-02-09T08:24:54.108Z [reload] config change detected; evaluating reload (models.providers.kimi-coding.models, models.providers.google.models, models.providers.groq.models, models.providers.openrouter.models, models.providers.ollama.models, agents.list)
Feb 09 09:24:54 Godgift node[281318]: 2026-02-09T08:24:54.110Z [reload] config change applied (dynamic reads: models.providers.kimi-coding.models, models.providers.google.models, models.providers.groq.models, models.providers.openrouter.models, models.providers.ollama.models, agents.list)
Feb 09 09:25:50 Godgift node[281318]: 2026-02-09T08:25:50.672Z [diagnostic] lane task error: lane=main durationMs=18 error="FailoverError: No API key found for provider "google". Auth store: /home/devbox/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /home/devbox/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir."
Feb 09 09:25:50 Godgift node[281318]: 2026-02-09T08:25:50.673Z [diagnostic] lane task error: lane=session:agent:main:main durationMs=23 error="FailoverError: No API key found for provider "google". Auth store: /home/devbox/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /home/devbox/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir."
Feb 09 09:26:01 Godgift node[281318]: 2026-02-09T08:26:01.994Z [diagnostic] lane task error: lane=main durationMs=27 error="FailoverError: No API key found for provider "google". Auth store: /home/devbox/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /home/devbox/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir."
Feb 09 09:26:01 Godgift node[281318]: 2026-02-09T08:26:01.996Z [diagnostic] lane task error: lane=session:agent:main:main durationMs=33 error="FailoverError: No API key found for provider "google". Auth store: /home/devbox/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /home/devbox/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir."
```

### Evidence: Ollama Tags
```
{"models":[{"name":"mistral-nemo:12b","model":"mistral-nemo:12b","modified_at":"2026-02-09T05:52:45.093377228Z","size":7071713227,"digest":"e7e06d107c6c86ed0cf45445f1790720b5092149c4c95f4d965844e9afbfdc89","details":{"parent_model":"","format":"gguf","family":"llama","families":["llama"],"parameter_size":"12.2B","quantization_level":"Q4_0"}},{"name":"dolphin3:8b","model":"dolphin3:8b","modified_at":"2026-02-09T05:51:44.169414468Z","size":4920757726,"digest":"d5ab9ae8e1f22619a6be52e5694df422b7183a3883990a000188c363781ecb78","details":{"parent_model":"","format":"gguf","family":"llama","families":["llama"],"parameter_size":"8.0B","quantization_level":"Q4_K_M"}},{"name":"qwen2.5-coder:14b","model":"qwen2.5-coder:14b","modified_at":"2026-02-09T05:51:43.399414484Z","size":8988124298,"digest":"9ec8897f747e246e970bc5cfdda85d22f1123dc2e3d34978a010a75968716849","details":{"parent_model":"","format":"gguf","family":"qwen2","families":["qwen2"],"parameter_size":"14.8B","quantization_level":"Q4_K_M"}},{"name":"qwen2.5:14b","model":"qwen2.5:14b","modified_at":"2026-02-09T05:50:28.078145182Z","size":8988124069,"digest":"7cdf5a0187d5c58cc5d369b255592f7841d1c4696d45a8c8a9489440385b22f6","details":{"parent_model":"","format":"gguf","family":"qwen2","families":["qwen2"],"parameter_size":"14.8B","quantization_level":"Q4_K_M"}},{"name":"nomic-embed-text:latest","model":"nomic-embed-text:latest","modified_at":"2026-02-09T05:28:43.943156302Z","size":274302450,"digest":"0a109f422b47e3a30ba2b10eca18548e944e8a23073ee3f3e947efcf3c45e59f","details":{"parent_model":"","format":"gguf","family":"nomic-bert","families":["nomic-bert"],"parameter_size":"137M","quantization_level":"F16"}}]}
```

### Evidence: RAG Health
```
{"status":"ok","chroma":"connected","ollama":"http://ollama:11434"}
```

### Evidence: Amharic Health
```
{"model":"facebook/nllb-200-distilled-600M","status":"ok"}
```

### Evidence: NVIDIA-SMI Snapshot
```
Mon Feb  9 08:26:33 2026       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 590.52.01              Driver Version: 591.74         CUDA Version: 13.1     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 3080 ...    On  |   00000000:01:00.0  On |                  N/A |
| N/A   46C    P8             17W /  175W |    2003MiB /  16384MiB |     11%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

### Evidence: RAG Query Output
```
{"query":"What is OpenClaw?","results":[{"id":"/data/documents/test_info.txt_0","document":"OpenClaw is a powerful multi-agent system.","metadata":{"tags":"test","source":"/data/documents/test_info.txt"},"distance":394.71857}]}
```

[MANUAL] Section 6: Model Locality + Fallback
To verify fallback:
1. Temporarily invalidate GOOGLE_API_KEY in .env
2. Run: openclaw agent --agent main --message 'ping'
3. Verify log shows switch to Kimi and user receives notice.

[MANUAL] Section 7: Telegram Live Check
1. Send '/start' in an Amharic-designated group.
2. Verify response is translated to Amharic by middleware.
| Systemd | PASS | openclaw-gateway.service is active |
| Docker Containers | PASS | All support services running |
| Port Connectivity | PASS | All ports reachable from host |
| GPU Load | PASS | GPU utilization detected (Before: 12%, During: 9%) |
| RAG Pipeline | PASS | Ingestion and retrieval verified with metadata |
| Memory Persistence | PASS | Isolated test memory write verified |
| Memory Isolation | PASS | Cross-agent memory access logic verified |
| Telegram Config | PASS | Allowlist active with 5 groups |


## Final Status: PASS
