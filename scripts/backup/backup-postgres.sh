#!/bin/bash
# File: scripts/backup/backup-postgres.sh
# PostgreSQL backup script

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/postgres"
BACKUP_FILE="$BACKUP_DIR/huntmaster_postgres_${TIMESTAMP}.sql.gz"

echo "Starting PostgreSQL backup at $(date)"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Perform backup
PGPASSWORD=$POSTGRES_PASSWORD pg_dump \
    -h postgres \
    -U huntmaster \
    -d huntmaster \
    --verbose \
    --no-owner \
    --no-acl \
    | gzip > "$BACKUP_FILE"

echo "PostgreSQL backup completed: $BACKUP_FILE"

# Verify backup
if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
    echo "Backup size: $SIZE"
    
    # Test backup integrity
    gunzip -t "$BACKUP_FILE" && echo "Backup integrity verified"
else
    echo "ERROR: Backup file not created!"
    exit 1
fi