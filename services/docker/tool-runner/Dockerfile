FROM python:3.12-slim

# Install curl for controlled internal probes.
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY services/docker/tool-runner/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY services/docker/tool-runner/app /app/app

# NOTE: This container spawns short-lived "runner-job" containers using the Docker socket.
# The job containers provide the actual filesystem/network sandboxing for untrusted execution.
# This service itself should run only trusted code and accepts requests only from sandbox-guard
# (token-authenticated).
ENV HOST_WORKSPACES_ROOT=/home/devbox/.openclaw/workspaces
ENV SANDBOX_NET_NAME=openclaw_sandbox_net
ENV JOB_IMAGE=openclaw-tool-runner:local
ENV PYTHONUNBUFFERED=1

EXPOSE 18889

CMD ["python", "-m", "uvicorn", "app.server:app", "--host", "0.0.0.0", "--port", "18889"]
