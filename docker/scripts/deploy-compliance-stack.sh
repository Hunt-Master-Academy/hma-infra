#!/bin/bash
# Deploy HMA Compliance Stack
# Complete deployment automation for CISO Assistant + Wazuh SIEM

set -e

echo "=================================================="
echo "HMA Compliance Stack - Complete Deployment"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to docker directory
cd "$(dirname "$0")"

echo -e "${BLUE}Step 1: Pre-deployment Checks${NC}"
echo "------------------------------"

# Check if main stack is running
if ! docker ps | grep -q hma_postgres; then
    echo -e "${RED}ERROR: Main HMA stack is not running${NC}"
    echo "Please start the main stack first:"
    echo "  docker compose up -d"
    exit 1
fi
echo -e "${GREEN}✓ Main HMA stack is running${NC}"

# Check kernel parameter for Wazuh
CURRENT_MAP_COUNT=$(sysctl -n vm.max_map_count)
if [ "$CURRENT_MAP_COUNT" -lt 262144 ]; then
    echo -e "${YELLOW}⚠ Setting vm.max_map_count for Wazuh/OpenSearch${NC}"
    sudo sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo -e "${GREEN}✓ Kernel parameter set${NC}"
else
    echo -e "${GREEN}✓ Kernel parameter already configured${NC}"
fi

# Check for environment file
if [ ! -f .env.compliance ]; then
    echo -e "${YELLOW}⚠ Creating .env.compliance from template${NC}"
    cp .env.compliance.example .env.compliance
    echo -e "${RED}IMPORTANT: Edit .env.compliance and set secure passwords!${NC}"
    echo "Press Enter to continue after editing, or Ctrl+C to abort..."
    read
fi
echo -e "${GREEN}✓ Environment file exists${NC}"

echo ""
echo -e "${BLUE}Step 2: Initialize Databases${NC}"
echo "-----------------------------"
./scripts/init-compliance-dbs.sh

echo ""
echo -e "${BLUE}Step 3: Initialize Storage${NC}"
echo "--------------------------"
./scripts/init-compliance-storage.sh

echo ""
echo -e "${BLUE}Step 4: Deploy Compliance Stack${NC}"
echo "--------------------------------"
docker compose -f docker-compose.compliance.yml up -d

echo ""
echo -e "${BLUE}Step 5: Wait for Services to Start${NC}"
echo "-----------------------------------"
echo "Waiting 60 seconds for services to initialize..."
sleep 60

echo ""
echo -e "${BLUE}Step 6: Run CISO Assistant Migrations${NC}"
echo "--------------------------------------"
docker exec hma_ciso_backend python manage.py migrate

echo ""
echo -e "${BLUE}Step 7: Load Compliance Frameworks${NC}"
echo "-----------------------------------"
echo "Loading ISO 27001, SOC 2, GDPR, CCPA frameworks..."
# Note: CISO Assistant may auto-load frameworks on first run
docker exec hma_ciso_backend python manage.py loaddata frameworks || echo "Frameworks may already be loaded"

echo ""
echo -e "${BLUE}Step 8: Create Admin User${NC}"
echo "-------------------------"
echo "Creating CISO Assistant superuser..."
docker exec hma_ciso_backend python manage.py createsuperuser --noinput --email "${CISO_ADMIN_EMAIL:-admin@huntmasteracademy.com}" || echo "Superuser may already exist"

echo ""
echo -e "${BLUE}Step 9: Verify Deployment${NC}"
echo "-------------------------"
docker compose -f docker-compose.compliance.yml ps

echo ""
echo -e "${GREEN}=================================================="
echo "Compliance Stack Deployment Complete!"
echo "==================================================${NC}"
echo ""
echo "Access Points:"
echo "-------------"
echo -e "${BLUE}CISO Assistant (GRC Platform):${NC}"
echo "  URL: https://localhost:8443"
echo "  Email: ${CISO_ADMIN_EMAIL:-admin@huntmasteracademy.com}"
echo "  Password: (as set in .env.compliance)"
echo ""
echo -e "${BLUE}Wazuh Dashboard (SIEM):${NC}"
echo "  URL: https://localhost:8444"
echo "  Username: admin"
echo "  Password: admin (change on first login)"
echo ""
echo -e "${BLUE}Wazuh API:${NC}"
echo "  URL: https://localhost:55000"
echo "  Username: ${WAZUH_API_USER:-hma_wazuh_api}"
echo "  Password: (as set in .env.compliance)"
echo ""
echo -e "${BLUE}MinIO Console (Evidence Storage):${NC}"
echo "  URL: http://localhost:9001"
echo "  Buckets: hma-compliance-evidence, hma-wazuh-archives"
echo ""
echo "Next Steps:"
echo "----------"
echo "1. Log into CISO Assistant and configure your first risk assessment"
echo "2. Configure Wazuh agents for container monitoring"
echo "3. Set up AWS CloudWatch integration in Wazuh"
echo "4. Configure Prometheus to scrape Wazuh metrics"
echo "5. Create Grafana dashboards for compliance monitoring"
echo ""
echo "Documentation:"
echo "  - COMPLIANCE_STACK_ASSESSMENT.md (deployment guide)"
echo "  - Compliance_Security_Development.md (tool analysis)"
echo ""
echo -e "${YELLOW}⚠ SECURITY REMINDER:${NC}"
echo "  - Change default passwords immediately"
echo "  - Review and harden security settings for production"
echo "  - Enable TLS with proper certificates for production"
echo "  - Configure backup procedures"
echo ""
