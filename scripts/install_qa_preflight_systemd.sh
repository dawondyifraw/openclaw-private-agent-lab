#!/usr/bin/env bash
# Installs systemd user drop-in so qa_preflight runs before gateway start.
set -euo pipefail

UNIT="openclaw-gateway.service"
DROPIN_DIR="${HOME}/.config/systemd/user/${UNIT}.d"
DROPIN_FILE="${DROPIN_DIR}/10-qa-preflight.conf"
ROOT="/home/devbox/.openclaw"

mkdir -p "${DROPIN_DIR}"

cat > "${DROPIN_FILE}" <<EOF
[Service]
Environment=OPENCLAW_QA_PREFLIGHT_RUN_STRICT=0
Environment=OPENCLAW_QA_PREFLIGHT_TIMEOUT_S=90
ExecStartPre=${ROOT}/scripts/qa_preflight.sh
EOF

systemctl --user daemon-reload

echo "Installed: ${DROPIN_FILE}"
echo "To enable strict preflight on every start, set:"
echo "  systemctl --user edit ${UNIT}"
echo "and add: Environment=OPENCLAW_QA_PREFLIGHT_RUN_STRICT=1"
echo
echo "Restart gateway to apply:"
echo "  systemctl --user restart ${UNIT}"

