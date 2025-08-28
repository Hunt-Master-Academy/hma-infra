#!/usr/bin/env bash
set -euo pipefail

echo "Setting up HMA content development environment..."

CONTENT_PATH="${HMA_CONTENT_PATH:-../hma-content}"

if [ ! -d "$CONTENT_PATH" ]; then
  echo "Cloning hma-content repository to $CONTENT_PATH..."
  git clone https://github.com/huntmaster/hma-content.git "$CONTENT_PATH" || true
  if command -v git-lfs >/dev/null 2>&1; then
    (cd "$CONTENT_PATH" && git lfs install && git lfs pull || true)
  fi
fi

# Ensure docker network is up and start content bridge
docker compose -f docker/docker-compose.yml up -d content-bridge

# Wait for health
for i in {1..30}; do
  if curl -fsS http://localhost:8090/health >/dev/null 2>&1; then
    echo "Content bridge healthy."
    exit 0
  fi
  sleep 1
 done

echo "Content bridge did not become healthy in time." >&2
exit 1
