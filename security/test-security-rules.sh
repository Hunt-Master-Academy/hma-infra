#!/bin/bash
# [20251108-SECURITY-004] Test security detection rules

set -e

API_URL="${API_URL:-http://localhost:3001}"
TEST_TYPE="${1:-all}"

echo "🧪 HMA Security Rules Testing"
echo "=============================="
echo "API: $API_URL"
echo "Test Type: $TEST_TYPE"
echo ""

# Function to test failed admin logins
test_failed_logins() {
    echo "📧 Test 1: Multiple Failed Admin Login Attempts"
    echo "Expected: Trigger after 5 failed attempts from same IP in 10 minutes"
    echo "Severity: HIGH"
    echo ""
    
    for i in {1..6}; do
        echo -n "  Attempt $i: "
        RESPONSE=$(curl -s -X POST "$API_URL/api/admin/auth/login" \
            -H "Content-Type: application/json" \
            -d "{\"email\":\"attacker-$(date +%s)@test.com\",\"password\":\"wrongpass\"}")
        
        if echo "$RESPONSE" | grep -q "error"; then
            echo "✅ Failed as expected"
        else
            echo "⚠️  Unexpected response: $RESPONSE"
        fi
        
        sleep 1
    done
    
    echo ""
    echo "✅ Test complete. Check Kibana for alert in 5-10 minutes."
    echo ""
}

# Function to test unauthorized access
test_unauthorized_access() {
    echo "🔒 Test 2: Unauthorized Admin Access Attempt"
    echo "Expected: Detect 403 responses on /api/admin/* endpoints"
    echo "Severity: HIGH"
    echo ""
    
    ENDPOINTS=(
        "/api/admin/users"
        "/api/admin/subscription-plans"
        "/api/admin/credits/adjust"
        "/api/admin/storage/buckets"
    )
    
    for endpoint in "${ENDPOINTS[@]}"; do
        echo -n "  Testing $endpoint: "
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer invalid_token_test_$(date +%s)" \
            "$API_URL$endpoint")
        
        if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "500" ]; then
            echo "✅ Got $HTTP_CODE"
        else
            echo "⚠️  Unexpected: $HTTP_CODE"
        fi
        
        sleep 0.5
    done
    
    echo ""
    echo "✅ Test complete. Check Kibana for alerts."
    echo ""
}

# Function to test authentication spike
test_auth_spike() {
    echo "🌊 Test 3: Failed Authentication Spike"
    echo "Expected: Detect 20+ failed auth attempts from same IP"
    echo "Severity: MEDIUM"
    echo ""
    
    echo "  Generating 25 failed authentication attempts..."
    for i in {1..25}; do
        echo -n "."
        curl -s -X POST "$API_URL/api/auth/login" \
            -H "Content-Type: application/json" \
            -d "{\"email\":\"user$i@test.com\",\"password\":\"wrong\"}" > /dev/null
        
        if [ $((i % 10)) -eq 0 ]; then
            echo " $i"
        fi
        
        sleep 0.2
    done
    
    echo ""
    echo "✅ Test complete. Check Kibana for alert in 5-10 minutes."
    echo ""
}

# Function to test slow transactions
test_slow_transactions() {
    echo "🐌 Test 4: Slow Transaction Performance"
    echo "Expected: Detect transactions over 5 seconds"
    echo "Severity: LOW"
    echo ""
    
    echo "  Note: This requires actual slow API responses."
    echo "  You may need to manually simulate this by:"
    echo "  1. Temporarily adding sleep(6000) to an endpoint"
    echo "  2. Calling that endpoint multiple times"
    echo "  3. Or running a load test with many concurrent requests"
    echo ""
    echo "  Skipping automated test for this rule."
    echo ""
}

# Function to test database connection failures
test_database_failures() {
    echo "🗄️  Test 5: Database Connection Failures"
    echo "Expected: Detect 5+ database connection errors in 10 minutes"
    echo "Severity: MEDIUM"
    echo ""
    
    echo "  Note: This requires actual database connectivity issues."
    echo "  To test manually:"
    echo "  1. docker-compose stop hma_postgres"
    echo "  2. Make 5+ API calls that hit database"
    echo "  3. docker-compose start hma_postgres"
    echo ""
    echo "  Skipping automated test for this rule."
    echo ""
}

# Function to generate test traffic
generate_normal_traffic() {
    echo "📊 Generating Normal Traffic (Baseline)"
    echo "========================================"
    echo ""
    
    ENDPOINTS=(
        "/health"
        "/api/courses"
        "/api/auth/me"
    )
    
    for i in {1..20}; do
        endpoint="${ENDPOINTS[$((RANDOM % ${#ENDPOINTS[@]}))]}"
        echo -n "."
        curl -s "$API_URL$endpoint" > /dev/null
        sleep 0.5
    done
    
    echo ""
    echo "✅ Normal traffic generated (20 requests)."
    echo ""
}

# Main test execution
case $TEST_TYPE in
    "failed-logins"|"1")
        test_failed_logins
        ;;
    "unauthorized"|"2")
        test_unauthorized_access
        ;;
    "auth-spike"|"3")
        test_auth_spike
        ;;
    "slow"|"4")
        test_slow_transactions
        ;;
    "database"|"5")
        test_database_failures
        ;;
    "normal")
        generate_normal_traffic
        ;;
    "all")
        echo "Running all automated tests..."
        echo ""
        test_failed_logins
        sleep 2
        test_unauthorized_access
        sleep 2
        test_auth_spike
        sleep 2
        generate_normal_traffic
        
        echo "=============================="
        echo "✅ All automated tests complete!"
        echo ""
        echo "Manual tests available:"
        echo "  - Slow transactions (requires code changes)"
        echo "  - Database failures (requires stopping postgres)"
        echo ""
        echo "View alerts:"
        echo "  http://localhost:5601/app/security/alerts"
        echo ""
        echo "⏰ Alerts may take 5-10 minutes to appear (rule execution interval)"
        ;;
    *)
        echo "Usage: $0 [test-type]"
        echo ""
        echo "Available tests:"
        echo "  failed-logins (1)  - Test failed admin login detection"
        echo "  unauthorized (2)   - Test unauthorized access detection"
        echo "  auth-spike (3)     - Test authentication spike detection"
        echo "  slow (4)          - Info about slow transaction testing"
        echo "  database (5)      - Info about database failure testing"
        echo "  normal            - Generate baseline normal traffic"
        echo "  all               - Run all automated tests"
        echo ""
        echo "Example:"
        echo "  $0 failed-logins"
        echo "  $0 all"
        exit 1
        ;;
esac
