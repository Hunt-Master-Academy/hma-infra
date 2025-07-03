#!/bin/bash
# File: scripts/restore/restore-full.sh
# Full system restore script

set -e
set -o pipefail

MANIFEST_FILE=$1
RESTORE_TARGET=${2:-/workspace/restore}

if [ -z "$MANIFEST_FILE" ] || [ ! -f "$MANIFEST_FILE" ]; then
    echo "Usage: $0 <path_to_manifest.json> [restore_target]"
    echo "Example: $0 /backups/manifest_20240115_103000.json /workspace/restore"
    exit 1
fi

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "ERROR: 'jq' is not installed. Please install it to parse the manifest."
    exit 1
fi

BACKUP_DIR=$(dirname "$MANIFEST_FILE")

echo "=== Starting full restore from manifest: $MANIFEST_FILE ==="

# 1. Restore PostgreSQL
echo "Restoring PostgreSQL..."
POSTGRES_FILENAME=$(jq -r '.backups.postgres' "$MANIFEST_FILE")
POSTGRES_BACKUP_PATH="$BACKUP_DIR/postgres/$POSTGRES_FILENAME"

if [ -f "$POSTGRES_BACKUP_PATH" ]; then
    echo "Found PostgreSQL backup: $POSTGRES_BACKUP_PATH"
    gunzip -c "$POSTGRES_BACKUP_PATH" | \
    PGPASSWORD=$POSTGRES_PASSWORD psql \
        -h postgres \
        -U huntmaster \
        -d huntmaster
    echo "PostgreSQL restored"
else
    echo "WARNING: PostgreSQL backup file not found at $POSTGRES_BACKUP_PATH"
fi

# 2. Restore Redis
echo "Restoring Redis..."
REDIS_FILENAME=$(jq -r '.backups.redis' "$MANIFEST_FILE")
REDIS_BACKUP_PATH="$BACKUP_DIR/redis/$REDIS_FILENAME"

if [ -f "$REDIS_BACKUP_PATH" ]; then
    echo "Found Redis backup: $REDIS_BACKUP_PATH"
    redis-cli -h redis FLUSHALL
    docker cp "$REDIS_BACKUP_PATH" huntmaster-redis:/data/dump.rdb
    docker restart huntmaster-redis
    echo "Redis restored"
else
    echo "WARNING: Redis backup file not found at $REDIS_BACKUP_PATH"
fi

# 3. Restore application data
echo "Restoring application data..."
APP_FILENAME=$(jq -r '.backups.app_data' "$MANIFEST_FILE")
APP_BACKUP_PATH="$BACKUP_DIR/$APP_FILENAME"

if [ -f "$APP_BACKUP_PATH" ]; then
    echo "Found App Data backup: $APP_BACKUP_PATH"
    mkdir -p "$RESTORE_TARGET"
    tar -xzf "$APP_BACKUP_PATH" -C "$RESTORE_TARGET"
    echo "Application data restored to $RESTORE_TARGET"
else
    echo "WARNING: Application data backup file not found at $APP_BACKUP_PATH"
fi

echo "=== Restore completed ==="