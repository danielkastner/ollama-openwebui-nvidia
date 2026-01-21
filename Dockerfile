FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tini \
      openssh-server sudo zstd \
    && rm -rf /var/lib/apt/lists/*

# OpenSSH runtime dirs + host keys
RUN mkdir -p /var/run/sshd \
 && ssh-keygen -A

# SSH hardening defaults
RUN sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config \
 && echo "UsePAM yes" >> /etc/ssh/sshd_config \
 && echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config

# User app + sudo group
ARG SSH_USER=app
RUN useradd -m -s /bin/bash "${SSH_USER}" \
 && usermod -aG sudo "${SSH_USER}"

# Optional (bequem, aber weniger sicher): sudo ohne Passwort
# Wenn du das NICHT willst, einfach diese Zeile entfernen.
RUN echo "${SSH_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-${SSH_USER} \
 && chmod 0440 /etc/sudoers.d/99-${SSH_USER}

ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

EXPOSE 22 11434 8080

VOLUME ["/root/.ollama", "/app/backend/data"]

ENV OLLAMA_MODEL="llama3.1:8b" \
    OLLAMA_PULL="1" \
    OLLAMA_BASE_URL="http://0.0.0.0:11434" \
    OLLAMA_HOST="0.0.0.0:11434" \
    OLLAMA_DEBUG="1" \
    WEBUI_HOST="0.0.0.0" \
    WEBUI_PORT="8080" \
    SSH_USER="app" \
    SSH_ENABLE_PASSWORD="0"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY environment/runpod/environment.sh /environment/runpod/environment.sh
RUN chmod +x /environment/runpod/environment.sh
COPY environment/vastai/environment.sh /environment/vastai/environment.sh
RUN chmod +x /environment/vastai/environment.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
