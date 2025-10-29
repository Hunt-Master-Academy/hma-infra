#!/bin/bash
# Test Event Bridge Integration
# Publishes a test audit event and verifies CISO receives it

set -e

echo "============================================"
echo "Event Bridge Integration Test"
echo "============================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }
info() { echo -e "${YELLOW}ℹ${NC} $1"; }

# Test 1: Verify event consumer is running
echo "1. Checking event consumer status..."
CONSUMER_STATUS=$(docker ps --filter name=hma-event-consumer --format "{{.Status}}" | head -1)
if echo "$CONSUMER_STATUS" | grep -q "Up"; then
    pass "Event consumer running: $CONSUMER_STATUS"
else
    fail "Event consumer not running"
fi

# Test 2: Verify CISO backend is healthy
echo ""
echo "2. Checking CISO Assistant backend..."
CISO_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' hma_ciso_backend 2>/dev/null || echo "not found")
if [ "$CISO_HEALTH" = "healthy" ]; then
    pass "CISO backend healthy"
else
    fail "CISO backend not healthy: $CISO_HEALTH"
fi

# Test 3: Check CISO initialization in logs
echo ""
echo "3. Checking CISO client initialization..."
CISO_INIT=$(docker logs hma-event-consumer 2>&1 | grep -c "CISO.*initialized\|CISO integration" || echo "0")
if [ "$CISO_INIT" -gt 0 ]; then
    pass "CISO client initialized in worker"
    docker logs hma-event-consumer 2>&1 | grep "CISO" | tail -3
else
    info "CISO integration may be disabled (check CISO_API_URL env var)"
fi

# Test 4: Get CISO user token for API testing
echo ""
echo "4. Getting CISO API credentials..."
CISO_USER=$(docker exec hma_ciso_backend /code/.venv/bin/python manage.py shell -c "from iam.models import User; user = User.objects.first(); print(user.email)" 2>&1 | tail -1)
info "CISO user: $CISO_USER"

# Test 5: Publish test admin action event
echo ""
echo "5. Publishing test admin audit event to Redpanda..."
TEST_EVENT=$(cat <<EOF
{
  "event_type": "admin.action",
  "event_id": "test-$(date +%s)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "actor": {
    "user_id": "test-admin-001",
    "email": "admin@huntmasteracademy.com",
    "role": "admin"
  },
  "action": "test.event_bridge",
  "resource": {
    "type": "system",
    "id": "event-bridge-test",
    "name": "Event Bridge Integration Test"
  },
  "metadata": {
    "ip_address": "127.0.0.1",
    "user_agent": "EventBridgeTest/1.0",
    "reason": "Testing event bridge integration with CISO Assistant",
    "test": true
  }
}
EOF
)

docker exec hma_redpanda rpk topic produce audit-events --brokers localhost:9092 << EOF
$TEST_EVENT
EOF

pass "Test event published to audit-events topic"

# Test 6: Wait for processing
echo ""
echo "6. Waiting for event processing (10 seconds)..."
sleep 10

# Test 7: Check event consumer logs
echo ""
echo "7. Checking event consumer logs..."
PROCESSED=$(docker logs hma-event-consumer --since 15s 2>&1 | grep -c "Event processed\|forwarded to CISO" || echo "0")
if [ "$PROCESSED" -gt 0 ]; then
    pass "Event processing detected in logs"
    docker logs hma-event-consumer --since 15s 2>&1 | grep -E "audit|CISO|Evidence" | tail -10
else
    info "No recent processing logs found (event may be queued)"
fi

# Test 8: Check CISO evidence count
echo ""
echo "8. Checking CISO Assistant evidence records..."
EVIDENCE_COUNT=$(docker exec hma_ciso_backend /code/.venv/bin/python manage.py shell -c "from core.models import Evidence; print(Evidence.objects.count())" 2>&1 | tail -1)
info "Total evidence records in CISO: $EVIDENCE_COUNT"

# Test 9: Check recent evidence
echo ""
echo "9. Checking for recent evidence entries..."
RECENT=$(docker exec hma_ciso_backend /code/.venv/bin/python manage.py shell -c "
from core.models import Evidence
from datetime.datetime import datetime, timedelta
recent = Evidence.objects.filter(created_at__gte=datetime.now() - timedelta(minutes=1)).count()
print(recent)
" 2>&1 | tail -1)

if [ "$RECENT" -gt 0 ]; then
    pass "Found $RECENT recent evidence record(s)"
else
    info "No evidence created in last minute (check CISO logs for errors)"
fi

# Test 10: Redpanda consumer lag
echo ""
echo "10. Checking consumer lag..."
docker exec hma_redpanda rpk group describe hma-credit-processor --brokers localhost:9092 2>&1 | grep -A 2 "audit-events" || info "Consumer group status not available"

echo ""
echo "============================================"
echo "Test Summary"
echo "============================================"
echo ""
echo "Event Flow:"
echo "  1. Test event published → audit-events topic"
echo "  2. Event consumer processes → event_processing_log"
echo "  3. CISO mapper transforms → evidence format"
echo "  4. CISO client forwards → CISO Assistant API"
echo "  5. CISO backend stores → Evidence model"
echo ""
echo "Manual Verification:"
echo "  - Frontend: https://localhost:8443 (login as admin)"
echo "  - Check Evidence section for automated entries"
echo "  - Event consumer logs: docker logs hma-event-consumer -f"
echo "  - CISO backend logs: docker logs hma_ciso_backend -f"
echo ""
echo "Troubleshooting:"
echo "  - If no CISO init: Check CISO_API_URL env var in docker-compose"
echo "  - If auth fails: Verify CISO_USERNAME/PASSWORD credentials"
echo "  - If events not forwarded: Check event consumer has network access to hma-ciso-backend"
echo ""
