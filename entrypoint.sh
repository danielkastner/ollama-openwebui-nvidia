#!/usr/bin/env bash
set -euo pipefail

# ----- SSH user setup -----
SSH_USER="${SSH_USER:-app}"
USER_HOME="$(getent passwd "$SSH_USER" | cut -d: -f6 || true)"
if [[ -z "${USER_HOME}" ]]; then
  echo "[entrypoint] SSH_USER '$SSH_USER' not found. Creating..."
  useradd -m -s /bin/bash "$SSH_USER"
  USER_HOME="$(getent passwd "$SSH_USER" | cut -d: -f6)"
fi

# Authorized keys (recommended)
if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
  echo "[entrypoint] Configuring SSH authorized_keys for ${SSH_USER}"
  install -d -m 700 -o "$SSH_USER" -g "$SSH_USER" "${USER_HOME}/.ssh"
  printf '%s\n' "${SSH_PUBLIC_KEY}" > "${USER_HOME}/.ssh/authorized_keys"
  chown "$SSH_USER:$SSH_USER" "${USER_HOME}/.ssh/authorized_keys"
  chmod 600 "${USER_HOME}/.ssh/authorized_keys"
fi

# Optional password auth (off by default)
if [[ -n "${SSH_PASSWORD:-}" ]]; then
  echo "[entrypoint] Setting SSH password for ${SSH_USER}"
  echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
fi

if [[ "${SSH_ENABLE_PASSWORD:-0}" == "1" ]]; then
  echo "[entrypoint] Enabling SSH password authentication"
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  sed -i 's/^KbdInteractiveAuthentication .*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
else
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
fi

# Start sshd (background)
echo "[entrypoint] Starting sshd..."
/usr/sbin/sshd -D -e &
SSHD_PID=$!

# ---- Installing Python and OpenWebUI ----
if [[ "${DISABLE_WEBUI:-1}" == "1" ]]; then
  echo "[entrypoint] Skipping install of OpenWebUI (DISABLE_WEBUI=${DISABLE_WEBUI})."
else
  echo "[entrypoint] Installing Python"
  apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv

  # venv anlegen und Open WebUI dort installieren
  echo "[entrypoint] Creating VENV for OpenWebUI and installing it"
  python3 -m venv /opt/webui-venv \
   && /opt/webui-venv/bin/pip install --no-cache-dir --upgrade pip \
   && /opt/webui-venv/bin/pip install --no-cache-dir open-webui
fi

# ---- Installing Ollama ----
echo "[entrypoint] Installing Ollama via fetching Script"
curl -fsSL https://ollama.com/install.sh | sh

# ----- Ollama -----
echo "[entrypoint] Starting ollama serve..."
OLLAMA_CONTEXT_LENGTH=${OLLAMA_CONTEXT_LENGTH:-131072} OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-24h} ollama serve >/var/log/ollama.log 2>&1 &
OLLAMA_PID=$!

echo "[entrypoint] Waiting for Ollama API..."
for i in {1..60}; do
  if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  echo "[entrypoint] ERROR: Ollama API did not become ready in time."
  kill "${OLLAMA_PID}" "${SSHD_PID}" 2>/dev/null || true
  exit 1
fi

if [[ "${OLLAMA_PULL:-1}" == "1" ]]; then
  MODEL="${OLLAMA_MODEL:-}"
  if [[ -z "${MODEL}" ]]; then
    echo "[entrypoint] ERROR: OLLAMA_MODEL is empty but OLLAMA_PULL=1"
    kill "${OLLAMA_PID}" "${SSHD_PID}" 2>/dev/null || true
    exit 1
  fi
  echo "[entrypoint] Pulling model: ${MODEL}"
  ollama pull "${MODEL}"
else
  echo "[entrypoint] Skipping model pull (OLLAMA_PULL=${OLLAMA_PULL})."
fi

# ---- Print Environment Variables ----
if [[ "${ENVIRONMENT:-}" == "RUNPOD" ]]; then
  echo "[entrypoint] Printing Environment for runpod.io"
  ./environment/runpod/environment.sh
elif [[ "${ENVIRONMENT:-}" == "VASTAI" ]]; then
  echo "[entrypoint] Printing Environment for Vast.ai"
  ./environment/vastai/environment.sh
else
  echo "[entrypoint] Environment not set or Value '${ENVIRONMENT}' not in ['RUNPOD', 'VASTAI']"
fi

# ----- Open WebUI (foreground) if enabled-----
if [[ "${DISABLE_WEBUI:-1}" == "1" ]]; then
  echo "[entrypoint] Open WebUI disabled, will sleep instead...";
  exec sleep infinity
else
  echo "[entrypoint] Starting Open WebUI..."
  exec /opt/webui-venv/bin/open-webui serve --host "${WEBUI_HOST:-0.0.0.0}" --port "${WEBUI_PORT:-8080}"
fi
