#!/bin/bash
#
# CISO Assistant Database Restore Script
#
# Restores PostgreSQL database from MinIO backup
#
# Usage:
#   ./restore-ciso-database.sh <backup_file>
#   ./restore-ciso-database.sh ciso_assistant_20251023_020000.sql.gz
#

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="hma_postgres"
POSTGRES_USER="ciso_admin"
POSTGRES_DB="ciso_assistant"
STAGING_DB="ciso_assistant_staging"
MINIO_BUCKET="hma-compliance-evidence"
MINIO_PREFIX="backups/database"
RESTORE_DIR="/tmp/ciso-restore"

# Check arguments
if [ $# -eq 0 ]; then
    echo "❌ Error: No backup file specified"
    echo ""
    echo "Usage: $0 <backup_file>"
    echo ""
    echo "Available backups:"
    docker exec hma_minio mc ls "local/${MINIO_BUCKET}/${MINIO_PREFIX}/" | grep "\.sql\.gz$" | tail -10
    exit 1
fi

BACKUP_FILE="$1"
LOCAL_FILE="${RESTORE_DIR}/$(basename ${BACKUP_FILE})"
DECOMPRESSED_FILE="${LOCAL_FILE%.gz}"

# Ensure restore directory exists
mkdir -p "${RESTORE_DIR}"

echo "🔄 Starting CISO Assistant database restore..."
echo "   Backup: ${BACKUP_FILE}"

# Download from MinIO
echo "   Downloading from MinIO..."
docker exec hma_minio mc cp \
    "local/${MINIO_BUCKET}/${MINIO_PREFIX}/${BACKUP_FILE}" \
    "${LOCAL_FILE}"

# Verify checksum if available
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
if docker exec hma_minio mc stat "local/${MINIO_BUCKET}/${MINIO_PREFIX}/${CHECKSUM_FILE}" >/dev/null 2>&1; then
    echo "   Verifying checksum..."
    docker exec hma_minio mc cp \
        "local/${MINIO_BUCKET}/${MINIO_PREFIX}/${CHECKSUM_FILE}" \
        "${LOCAL_FILE}.sha256"
    
    EXPECTED_CHECKSUM=$(cat "${LOCAL_FILE}.sha256" | awk '{print $1}')
    ACTUAL_CHECKSUM=$(sha256sum "${LOCAL_FILE}" | awk '{print $1}')
    
    if [ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]; then
        echo "❌ Checksum mismatch!"
        echo "   Expected: ${EXPECTED_CHECKSUM}"
        echo "   Actual:   ${ACTUAL_CHECKSUM}"
        exit 1
    fi
    echo "   ✅ Checksum verified"
fi

# Decompress
echo "   Decompressing backup..."
gunzip -c "${LOCAL_FILE}" > "${DECOMPRESSED_FILE}"

# Create staging database
echo "   Creating staging database..."
docker exec "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" -d postgres -c \
    "DROP DATABASE IF EXISTS ${STAGING_DB};"
docker exec "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" -d postgres -c \
    "CREATE DATABASE ${STAGING_DB} WITH OWNER ${POSTGRES_USER};"

# Restore to staging
echo "   Restoring to staging database..."
docker exec -i "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" -d "${STAGING_DB}" \
    < "${DECOMPRESSED_FILE}"

# Verify restore
echo "   Verifying restore..."
TABLE_COUNT=$(docker exec "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" -d "${STAGING_DB}" -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
echo "   Tables restored: ${TABLE_COUNT}"

if [ "${TABLE_COUNT}" -lt 10 ]; then
    echo "❌ Restore verification failed: Too few tables (${TABLE_COUNT})"
    exit 1
fi

echo ""
echo "✅ Restore complete to staging database!"
echo ""
echo "   Staging DB: ${STAGING_DB}"
echo "   Tables: ${TABLE_COUNT}"
echo ""
echo "To promote to production:"
echo "   1. Stop CISO services: docker compose -f docker-compose.compliance.yml stop"
echo "   2. Rename databases:"
echo "      docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -d postgres -c \"ALTER DATABASE ${POSTGRES_DB} RENAME TO ${POSTGRES_DB}_old;\""
echo "      docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -d postgres -c \"ALTER DATABASE ${STAGING_DB} RENAME TO ${POSTGRES_DB};\""
echo "   3. Start CISO services: docker compose -f docker-compose.compliance.yml start"
echo "   4. Test thoroughly"
echo "   5. Drop old database: docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -d postgres -c \"DROP DATABASE ${POSTGRES_DB}_old;\""
echo ""

# Clean up
rm -f "${LOCAL_FILE}" "${LOCAL_FILE}.sha256" "${DECOMPRESSED_FILE}"
