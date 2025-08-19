#!/usr/bin/env bash
set -euo pipefail

# Redis cache stats
redis_cli() {
  docker compose -f docker/docker-compose.yml exec -T redis redis-cli -a "${REDIS_PASSWORD:-development_redis}" "$@"
}

echo "# Redis INFO stats"
redis_cli INFO | egrep 'uptime_in_seconds|connected_clients|maxmemory|used_memory_human|keyspace_hits|keyspace_misses' || true

echo "# Cache hit rate (approx)"
HITS=$(redis_cli INFO stats | awk -F: '/keyspace_hits:/ {print $2}' | tr -d '\r')
MISSES=$(redis_cli INFO stats | awk -F: '/keyspace_misses:/ {print $2}' | tr -d '\r')
TOTAL=$((HITS+MISSES))
if [[ $TOTAL -gt 0 ]]; then
  printf 'Hit rate: %.2f%%\n' "$(echo "scale=4; ($HITS/$TOTAL)*100" | bc)"
else
  echo 'Hit rate: N/A'
fi
