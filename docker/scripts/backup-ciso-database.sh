#!/bin/bash
#
# CISO Assistant Database Backup Script
# 
# Performs daily PostgreSQL backup and uploads to MinIO
# Run via cron: 0 2 * * * /path/to/backup-ciso-database.sh
#

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="hma_postgres"
POSTGRES_USER="ciso_admin"
POSTGRES_DB="ciso_assistant"
BACKUP_DIR="/tmp/ciso-backups"
MINIO_BUCKET="hma-compliance-evidence"
MINIO_PREFIX="backups/database"
RETENTION_DAYS=30

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/ciso_assistant_${TIMESTAMP}.sql"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

echo "🔄 Starting CISO Assistant database backup..."
echo "   Timestamp: ${TIMESTAMP}"

# Perform backup
echo "   Creating PostgreSQL dump..."
docker exec "${POSTGRES_CONTAINER}" pg_dump \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    > "${BACKUP_FILE}"

# Compress backup
echo "   Compressing backup..."
gzip "${BACKUP_FILE}"

# Calculate checksum
CHECKSUM=$(sha256sum "${COMPRESSED_FILE}" | awk '{print $1}')
echo "   SHA256: ${CHECKSUM}"

# Upload to MinIO
echo "   Uploading to MinIO..."
docker exec hma_minio mc cp \
    "/tmp/$(basename ${COMPRESSED_FILE})" \
    "local/${MINIO_BUCKET}/${MINIO_PREFIX}/$(basename ${COMPRESSED_FILE})" \
    2>&1 | grep -v "mc: <ERROR>" || true

# Create checksum file
echo "${CHECKSUM}  $(basename ${COMPRESSED_FILE})" > "${COMPRESSED_FILE}.sha256"
docker exec hma_minio mc cp \
    "/tmp/$(basename ${COMPRESSED_FILE}.sha256)" \
    "local/${MINIO_BUCKET}/${MINIO_PREFIX}/$(basename ${COMPRESSED_FILE}.sha256)" \
    2>&1 | grep -v "mc: <ERROR>" || true

# Clean up local files
rm -f "${COMPRESSED_FILE}" "${COMPRESSED_FILE}.sha256"

# Remove old backups from MinIO (keep last 30 days)
echo "   Cleaning old backups (retention: ${RETENTION_DAYS} days)..."
CUTOFF_DATE=$(date -d "${RETENTION_DAYS} days ago" +%Y%m%d)
docker exec hma_minio mc ls "local/${MINIO_BUCKET}/${MINIO_PREFIX}/" | while read -r line; do
    FILE_DATE=$(echo "$line" | awk '{print $6}' | sed 's/ciso_assistant_//' | sed 's/_.*//')
    if [[ "${FILE_DATE}" < "${CUTOFF_DATE}" ]]; then
        FILE_NAME=$(echo "$line" | awk '{print $6}')
        echo "   Removing old backup: ${FILE_NAME}"
        docker exec hma_minio mc rm "local/${MINIO_BUCKET}/${MINIO_PREFIX}/${FILE_NAME}" || true
    fi
done

echo "✅ Backup complete!"
echo "   File: ${MINIO_BUCKET}/${MINIO_PREFIX}/$(basename ${COMPRESSED_FILE})"
echo "   Size: $(du -h ${COMPRESSED_FILE} 2>/dev/null | awk '{print $1}' || echo 'N/A')"
echo "   SHA256: ${CHECKSUM}"
