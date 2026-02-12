
#!/bin/bash
echo "Starting OpenClaw Orchestrator..."
# NOTE:
# Earlier prompts mentioned "orchestrator" and "agents router".
# This container does NOT implement those.
# Orchestration and routing are handled by the host OpenClaw systemd service.

cd /app/services/amharic-translation
python3 amharic_translation_service.py

# Keep alive if python exits
tail -f /dev/null
