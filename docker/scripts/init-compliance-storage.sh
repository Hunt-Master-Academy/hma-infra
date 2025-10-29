#!/bin/bash
# Initialize MinIO storage for HMA Compliance Stack
# Creates buckets and sets policies for evidence collection

set -e

echo "=================================================="
echo "HMA Compliance Stack - Storage Initialization"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if MinIO container is running
if ! docker ps | grep -q hma_minio; then
    echo -e "${RED}ERROR: MinIO container (hma_minio) is not running${NC}"
    echo "Please start the main HMA stack first:"
    echo "  cd /home/xbyooki/projects/hma-infra/docker"
    echo "  docker compose up -d minio"
    exit 1
fi

echo -e "${GREEN}✓ MinIO container is running${NC}"
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
else
    MINIO_USER="minioadmin"
    MINIO_PASSWORD="minioadmin"
fi

echo "Creating compliance evidence bucket..."
echo "--------------------------------------"

# Create bucket using MinIO client inside container
docker exec hma_minio mc alias set local http://localhost:9000 ${MINIO_USER} ${MINIO_PASSWORD}
docker exec hma_minio mc mb local/hma-compliance-evidence --ignore-existing

echo -e "${GREEN}✓ Bucket 'hma-compliance-evidence' created${NC}"
echo ""

echo "Setting bucket policies..."
echo "-------------------------"

# Set bucket policy for CISO Assistant access (private by default)
docker exec hma_minio mc anonymous set none local/hma-compliance-evidence

echo -e "${GREEN}✓ Bucket policy configured (private)${NC}"
echo ""

echo "Creating additional compliance buckets..."
echo "-----------------------------------------"

# Wazuh log archives
docker exec hma_minio mc mb local/hma-wazuh-archives --ignore-existing
docker exec hma_minio mc anonymous set none local/hma-wazuh-archives
echo -e "${GREEN}✓ Bucket 'hma-wazuh-archives' created${NC}"

# Compliance reports
docker exec hma_minio mc mb local/hma-compliance-reports --ignore-existing
docker exec hma_minio mc anonymous set none local/hma-compliance-reports
echo -e "${GREEN}✓ Bucket 'hma-compliance-reports' created${NC}"

# Audit evidence
docker exec hma_minio mc mb local/hma-audit-evidence --ignore-existing
docker exec hma_minio mc anonymous set none local/hma-audit-evidence
echo -e "${GREEN}✓ Bucket 'hma-audit-evidence' created${NC}"

echo ""
echo "Verifying bucket creation..."
echo "---------------------------"
docker exec hma_minio mc ls local/ | grep hma-compliance

echo ""
echo -e "${GREEN}=================================================="
echo "Storage initialization complete!"
echo "==================================================${NC}"
echo ""
echo "Created buckets:"
echo "  - hma-compliance-evidence (CISO Assistant evidence storage)"
echo "  - hma-wazuh-archives (Wazuh log archives)"
echo "  - hma-compliance-reports (Generated compliance reports)"
echo "  - hma-audit-evidence (Audit trail evidence)"
echo ""
echo "Access MinIO console at: http://localhost:9001"
echo "  Username: ${MINIO_USER}"
echo "  Password: ${MINIO_PASSWORD}"
echo ""
