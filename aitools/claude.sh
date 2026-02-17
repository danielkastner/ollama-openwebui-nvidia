#!/usr/bin/env bash
set -euo pipefail
echo "[aitools] Use Claude Code with:"
echo "[aitools]" ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_BASE_URL=http://localhost:21434 ANTHROPIC_API_KEY=\"\" claude --model $OLLAMA_MODEL
