
FROM python:3.9-slim

WORKDIR /app

RUN pip install requests pyyaml flask

# Copy orchestrator code and configs
COPY ./services/amharic-translation /app/services/amharic-translation
COPY ./agents /app/agents
COPY ./openclaw.json /app/openclaw.json

# Entrypoint script placeholder
COPY ./services/docker/orchestrator/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
