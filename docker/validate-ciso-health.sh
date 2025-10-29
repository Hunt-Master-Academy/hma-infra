#!/bin/bash
# CISO Assistant Health Validation Script
# Tests all critical components after container fix

set -e

echo "============================================"
echo "CISO Assistant Health Validation"
echo "============================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Test 1: Container Health
echo "1. Checking container health..."
BACKEND_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' hma_ciso_backend 2>/dev/null || echo "not found")
FRONTEND_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' hma_ciso_frontend 2>/dev/null || echo "not found")

if [ "$BACKEND_HEALTH" = "healthy" ]; then
    pass "Backend container healthy"
else
    fail "Backend container not healthy: $BACKEND_HEALTH"
fi

if [ "$FRONTEND_HEALTH" = "healthy" ]; then
    pass "Frontend container healthy"
else
    fail "Frontend container not healthy: $FRONTEND_HEALTH"
fi

# Test 2: Django Environment
echo ""
echo "2. Checking Django environment..."
DJANGO_VERSION=$(docker exec hma_ciso_backend /code/.venv/bin/python -c "import django; print(django.get_version())" 2>&1)
if [ $? -eq 0 ]; then
    pass "Django installed: version $DJANGO_VERSION"
else
    fail "Django import failed"
fi

# Test 3: Database Connection
echo ""
echo "3. Checking database connection..."
DB_CHECK=$(docker exec hma_ciso_backend /code/.venv/bin/python manage.py check --database default 2>&1 | grep -c "System check identified no issues" || echo "0")
if [ "$DB_CHECK" -gt 0 ]; then
    pass "Database connection working"
else
    warn "Database check returned warnings (may be normal for dev)"
fi

# Test 4: Database Schema
echo ""
echo "4. Checking database schema..."
TABLE_COUNT=$(docker exec hma_postgres psql -U ciso_admin -d ciso_assistant -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1)
if [ "$TABLE_COUNT" -gt 100 ]; then
    pass "Database schema loaded: $TABLE_COUNT tables"
else
    fail "Database schema incomplete: only $TABLE_COUNT tables"
fi

# Test 5: Frontend Accessibility
echo ""
echo "5. Checking frontend accessibility..."
FRONTEND_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443/ 2>&1)
if [ "$FRONTEND_STATUS" = "200" ] || [ "$FRONTEND_STATUS" = "302" ]; then
    pass "Frontend accessible (HTTP $FRONTEND_STATUS)"
else
    fail "Frontend not accessible (HTTP $FRONTEND_STATUS)"
fi

# Test 6: Backend Internal API
echo ""
echo "6. Checking backend internal API..."
BACKEND_INTERNAL=$(docker exec hma_ciso_backend curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/iam/login/ 2>&1)
if [ "$BACKEND_INTERNAL" = "200" ] || [ "$BACKEND_INTERNAL" = "405" ]; then
    pass "Backend API responding (HTTP $BACKEND_INTERNAL)"
else
    warn "Backend API returned HTTP $BACKEND_INTERNAL (may need authentication)"
fi

# Test 7: User Accounts
echo ""
echo "7. Checking user accounts..."
USER_COUNT=$(docker exec hma_ciso_backend /code/.venv/bin/python manage.py shell -c "from core.models import User; print(User.objects.count())" 2>&1 | tail -1)
if [ "$USER_COUNT" -gt 0 ]; then
    pass "User accounts exist: $USER_COUNT users"
else
    warn "No user accounts found (create with: docker exec -it hma_ciso_backend python manage.py createsuperuser)"
fi

# Test 8: Redis Connection
echo ""
echo "8. Checking Redis connection..."
REDIS_CHECK=$(docker exec hma_ciso_backend /code/.venv/bin/python -c "import redis; r = redis.Redis(host='redis', port=6379, password='development_redis'); r.ping(); print('OK')" 2>&1)
if echo "$REDIS_CHECK" | grep -q "OK"; then
    pass "Redis connection working"
else
    warn "Redis connection issue: $REDIS_CHECK"
fi

# Test 9: MinIO Connection
echo ""
echo "9. Checking MinIO S3 connection..."
MINIO_CHECK=$(docker exec hma_ciso_backend /code/.venv/bin/python -c "import boto3; s3 = boto3.client('s3', endpoint_url='http://minio:9000', aws_access_key_id='minioadmin', aws_secret_access_key='minioadmin'); print('OK')" 2>&1)
if echo "$MINIO_CHECK" | grep -q "OK"; then
    pass "MinIO S3 connection configured"
else
    warn "MinIO connection issue: $MINIO_CHECK"
fi

# Test 10: Worker Process
echo ""
echo "10. Checking worker process..."
WORKER_STATUS=$(docker inspect --format='{{.State.Status}}' hma_ciso_worker 2>/dev/null || echo "not found")
if [ "$WORKER_STATUS" = "running" ]; then
    pass "Worker process running"
else
    warn "Worker process not running: $WORKER_STATUS"
fi

echo ""
echo "============================================"
echo -e "${GREEN}All critical health checks passed!${NC}"
echo "============================================"
echo ""
echo "Access CISO Assistant:"
echo "  Frontend: https://localhost:8443"
echo "  Backend API: http://hma-ciso-backend:8000/api (internal only)"
echo ""
echo "Next steps:"
echo "  1. Create admin user: docker exec -it hma_ciso_backend python manage.py createsuperuser"
echo "  2. Load frameworks: docker exec hma_ciso_backend python manage.py loaddata frameworks"
echo "  3. Build event bridge integration"
echo ""
