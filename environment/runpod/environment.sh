#!/usr/bin/env bash
set -euo pipefail

# VAST.ai specific Stuff
REQUIRED_VARS=(
  "RUNPOD_PUBLIC_IP"
  "RUNPOD_TCP_PORT_22"
  "RUNPOD_API_KEY"
  "RUNPOD_POD_ID"
  "SSH_USER"
  "SSH_PASSWORD"
)

missing=0

for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "[environment] WARN: Environment Variable '$var' is not set or empty." >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "[environment] WARN: Please specify all missing Variables!" >&2
  exit 0
fi

echo "[environment] Printing Infos from Environment Variables"
for var in "${REQUIRED_VARS[@]}"; do
  echo "  $var=${!var}"
done

echo "[environment] Connection Details:"
echo "[environment] sshpass -p ${SSH_PASSWORD} ssh -L 21434:localhost:11434 -p ${RUNPOD_TCP_PORT_22} -o StrictHostKeyChecking=no ${SSH_USER}@${RUNPOD_PUBLIC_IP}"