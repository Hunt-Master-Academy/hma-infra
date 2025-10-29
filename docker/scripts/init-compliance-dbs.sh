#!/bin/bash
# Initialize PostgreSQL databases for HMA Compliance Stack
# Run this script before deploying docker-compose.compliance.yml

set -e

echo "=================================================="
echo "HMA Compliance Stack - Database Initialization"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if PostgreSQL container is running
if ! docker ps | grep -q hma_postgres; then
    echo -e "${RED}ERROR: PostgreSQL container (hma_postgres) is not running${NC}"
    echo "Please start the main HMA stack first:"
    echo "  cd /home/xbyooki/projects/hma-infra/docker"
    echo "  docker compose up -d postgres"
    exit 1
fi

echo -e "${GREEN}✓ PostgreSQL container is running${NC}"
echo ""

# Load environment variables
if [ -f .env.compliance ]; then
    source .env.compliance
    echo -e "${GREEN}✓ Loaded .env.compliance${NC}"
else
    echo -e "${YELLOW}⚠ .env.compliance not found, using default passwords${NC}"
    CISO_DB_PASSWORD="change_me_ciso_db_pass"
fi

echo ""
echo "Creating CISO Assistant database..."
echo "-----------------------------------"

# Create CISO Assistant database
docker exec hma_postgres psql -U hma_admin -d postgres -c "CREATE DATABASE ciso_assistant;" 2>/dev/null || echo "Database ciso_assistant already exists"

# Create CISO Assistant user
docker exec hma_postgres psql -U hma_admin -d postgres -c "CREATE USER ciso_admin WITH PASSWORD '${CISO_DB_PASSWORD}';" 2>/dev/null || echo "User ciso_admin already exists"

# Grant privileges
docker exec hma_postgres psql -U hma_admin -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE ciso_assistant TO ciso_admin;"
docker exec hma_postgres psql -U hma_admin -d postgres -c "ALTER DATABASE ciso_assistant OWNER TO ciso_admin;"

# Grant schema privileges
docker exec hma_postgres psql -U hma_admin -d ciso_assistant -c "GRANT ALL ON SCHEMA public TO ciso_admin;"
docker exec hma_postgres psql -U hma_admin -d ciso_assistant -c "ALTER SCHEMA public OWNER TO ciso_admin;"

echo -e "${GREEN}✓ CISO Assistant database created${NC}"
echo ""

echo "Verifying database access..."
echo "----------------------------"

# Test connection
if docker exec hma_postgres psql -U ciso_admin -d ciso_assistant -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ CISO Assistant database is accessible${NC}"
else
    echo -e "${RED}✗ Failed to access CISO Assistant database${NC}"
    exit 1
fi

echo ""
echo "Database Summary:"
echo "----------------"
docker exec hma_postgres psql -U hma_admin -d postgres -c "\l" | grep -E "ciso_assistant|Name"

echo ""
echo -e "${GREEN}=================================================="
echo "Database initialization complete!"
echo "==================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Create MinIO bucket for evidence storage:"
echo "   ./scripts/init-compliance-storage.sh"
echo ""
echo "2. Deploy the compliance stack:"
echo "   docker compose -f docker-compose.compliance.yml up -d"
echo ""
echo "3. Run CISO Assistant migrations:"
echo "   docker exec hma_ciso_backend python manage.py migrate"
echo ""
echo "4. Create superuser:"
echo "   docker exec -it hma_ciso_backend python manage.py createsuperuser"
echo ""
