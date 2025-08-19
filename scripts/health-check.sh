#!/usr/bin/env bash
set -euo pipefail

# Simple health checks for services

echo "[health] Postgres"
docker ps --format '{{.Names}}' | grep -q '^hma_postgres$' && docker exec hma_postgres pg_isready -U hma || echo "postgres container not found"

echo "[health] Redis"
docker ps --format '{{.Names}}' | grep -q '^hma_redis$' && docker exec hma_redis redis-cli ping || echo "redis container not found"

echo "[health] MinIO"
docker ps --format '{{.Names}}' | grep -q '^hma_minio$' && curl -fsS http://localhost:9000/minio/health/live >/dev/null && echo OK || echo "minio unhealthy or not found"
