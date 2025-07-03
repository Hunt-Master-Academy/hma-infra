#!/bin/bash
# File: scripts/backup/run-all.sh
# Master backup orchestration script
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
LOG_FILE="/var/log/backup/backup_$(date +%Y%m%d).log"
BACKUP_ROOT="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Check for required environment variables
: "${S3_BUCKET:?Error: S3_BUCKET environment variable is not set.}"
: "${RETENTION_DAYS:?Error: RETENTION_DAYS environment variable is not set.}"

# Function to send failure notification
send_failure_notification() {
    local error_message="Huntmaster backup FAILED at $(date) on line $1."
    log "ERROR: $error_message"
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST "$SLACK_WEBHOOK" -H 'Content-type: application/json' --data "{\"text\":\"$error_message\"}"
    fi
}
trap 'send_failure_notification $LINENO' ERR

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to upload to S3
upload_to_s3() {
    local file=$1
    local s3_path=$2
    
    log "Uploading $file to S3..."
    # Let the script fail if upload fails (due to set -e)
    aws s3 cp "$file" "s3://$S3_BUCKET/$s3_path"
    log "S3 upload completed"
}

# Start backup process
log "=== Starting Huntmaster backup process ==="

# 1. Database backups
log "Backing up PostgreSQL..."
POSTGRES_BACKUP_LOG=$("$SCRIPT_DIR/backup-postgres.sh" 2>&1 | tee -a "$LOG_FILE")
POSTGRES_BACKUP=$(echo "$POSTGRES_BACKUP_LOG" | grep 'PostgreSQL backup completed:' | awk '{print $NF}')
upload_to_s3 "$POSTGRES_BACKUP" "postgres/$(basename $POSTGRES_BACKUP)"

log "Backing up Redis..."
REDIS_BACKUP_LOG=$("$SCRIPT_DIR/backup-redis.sh" 2>&1 | tee -a "$LOG_FILE")
REDIS_BACKUP=$(echo "$REDIS_BACKUP_LOG" | grep 'Redis backup completed:' | awk '{print $NF}')
upload_to_s3 "$REDIS_BACKUP" "redis/$(basename "$REDIS_BACKUP")"

# 2. Application data
log "Backing up application data..."
tar -czf "$BACKUP_ROOT/app_data_${TIMESTAMP}.tar.gz" \
    -C /workspace \
    --exclude='node_modules' \
    --exclude='build' \
    --exclude='.git' \
    data/ uploads/ config/

# 3. Git repository state
log "Capturing Git state..."
cd /workspace
git bundle create "$BACKUP_ROOT/git_bundle_${TIMESTAMP}.bundle" --all
git log --oneline -50 > "$BACKUP_ROOT/git_log_${TIMESTAMP}.txt"

# 4. Create backup manifest
cat > "$BACKUP_ROOT/manifest_${TIMESTAMP}.json" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "1.0",
    "backups": {
        "postgres": "$(basename "$POSTGRES_BACKUP")",
        "redis": "$(basename "$REDIS_BACKUP")",
        "app_data": "app_data_${TIMESTAMP}.tar.gz",
        "git_bundle": "git_bundle_${TIMESTAMP}.bundle"
    },
    "checksums": {
        "postgres": "$(sha256sum "$POSTGRES_BACKUP" | cut -d' ' -f1)",
        "redis": "$(sha256sum "$REDIS_BACKUP" | cut -d' ' -f1)"
    }
}
EOF

# 5. Cleanup old backups
log "Cleaning up old backups..."
find $BACKUP_ROOT -type f -mtime +$RETENTION_DAYS -delete

# 6. Verify backup integrity
log "Verifying backup integrity..."
find "$BACKUP_ROOT" -name "manifest_${TIMESTAMP}.json" -print0 | xargs -0 "$SCRIPT_DIR/verify-backups.sh"

log "=== Backup process completed ==="

# Send notification (optional)
if [ -n "$SLACK_WEBHOOK" ]; then
    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-type: application/json' \
        --data "{\"text\":\"Huntmaster backup completed successfully at $(date)\"}"
fi