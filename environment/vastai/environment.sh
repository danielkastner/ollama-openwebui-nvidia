#!/usr/bin/env bash
set -euo pipefail

# VAST.ai specific Stuff
REQUIRED_VARS=(
  "PUBLIC_IPADDR"
  "VAST_TCP_PORT_22"
  "VAST_TCP_PORT_8080"
  "VAST_TCP_PORT_11434"
  "SSH_USER"
  "CONTAINER_API_KEY"
  "CONTAINER_ID"
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
echo "[environment] OpenWebUI via ${PUBLIC_IPADDR}:${VAST_TCP_PORT_8080}"
echo "[environment] ollama via ${PUBLIC_IPADDR}:${VAST_TCP_PORT_11434}"
echo "[environment] sshpass -p ${SSH_PASSWORD} ssh -L 21434:localhost:11434 -p ${VAST_TCP_PORT_22} -o StrictHostKeyChecking=no ${SSH_USER}@${PUBLIC_IPADDR}"