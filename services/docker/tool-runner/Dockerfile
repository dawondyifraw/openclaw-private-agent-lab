FROM python:3.12-slim

# Install curl for controlled internal probes.
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY services/tool-runner/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY services/tool-runner/main.py /app/main.py

# Non-root runtime user.
RUN useradd -m -u 10001 appuser
USER 10001

ENV WORKSPACES_ROOT=/workspaces
ENV PYTHONUNBUFFERED=1

EXPOSE 18888

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "18888"]
