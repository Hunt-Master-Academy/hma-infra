#!/bin/bash
# File: scripts/backup/backup-redis.sh
# Redis backup script

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/redis"
BACKUP_FILE="$BACKUP_DIR/huntmaster_redis_${TIMESTAMP}.rdb"

echo "Starting Redis backup at $(date)"

mkdir -p "$BACKUP_DIR"

# Trigger Redis backup
redis-cli -h redis BGSAVE

# Wait for backup to complete by checking the bgsave_in_progress flag
echo "Waiting for BGSAVE to complete..."
while [[ $(redis-cli -h redis INFO persistence | grep 'bgsave_in_progress:1') ]]; do
    echo -n "."
    sleep 2
done
echo " BGSAVE finished."

# Copy backup file
docker exec huntmaster-redis cat /data/dump.rdb > "$BACKUP_FILE"

echo "Redis backup completed: $BACKUP_FILE"