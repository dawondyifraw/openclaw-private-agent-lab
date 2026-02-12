
#!/bin/bash

# Create app_net if not exists
docker network create app_net || true

# Connect running ollama container
echo "Connecting ollama to app_net..."
docker network connect app_net ollama || echo "Already connected."
