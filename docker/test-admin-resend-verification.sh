#!/bin/bash

# Test admin resend verification endpoint
# Usage: ./test-admin-resend-verification.sh

set -e

BASE_URL="http://localhost:3001"
USER_ID="70dd7760-e7ef-43ae-aa3b-f6f151fa6e4e"

echo "=========================================="
echo "Testing Admin Resend Verification Endpoint"
echo "=========================================="
echo ""

# Step 1: Login as admin to get cookies
echo "Step 1: Logging in as admin..."
COOKIE_FILE="/tmp/admin_cookies_$$.txt"
LOGIN_RESPONSE=$(curl -s -c "$COOKIE_FILE" -X POST "${BASE_URL}/api/admin/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "info@huntmasteracademy.com",
    "password": "Admin123!HMA"
  }')

# Check if login was successful
if echo "$LOGIN_RESPONSE" | grep -q "error"; then
  echo "❌ Failed to login as admin"
  echo "Response: $LOGIN_RESPONSE"
  rm -f "$COOKIE_FILE"
  exit 1
fi

echo "✅ Admin logged in successfully"
echo "Response:"
echo "$LOGIN_RESPONSE" | jq '.' 2>/dev/null || echo "$LOGIN_RESPONSE"
echo ""

# Step 2: Call resend verification endpoint with cookies
echo "Step 2: Testing resend verification endpoint..."
echo "User ID: $USER_ID"
echo ""

RESEND_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
  -b "$COOKIE_FILE" \
  "${BASE_URL}/api/admin/users/${USER_ID}/resend-verification" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Testing admin resend verification feature"
  }')

HTTP_CODE=$(echo "$RESEND_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESEND_RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
echo ""

# Cleanup cookies
rm -f "$COOKIE_FILE"

if [ "$HTTP_CODE" == "200" ]; then
  echo "✅ Admin resend verification successful"
  
  # Step 3: Check if token was created
  echo ""
  echo "Step 3: Verifying token was created in database..."
  TOKEN_CHECK=$(docker exec hma_postgres psql -U hma_admin -d hma_academy -t -c \
    "SELECT token FROM email_verification_tokens WHERE user_id = '$USER_ID' ORDER BY created_at DESC LIMIT 1;")
  
  if [ -n "$TOKEN_CHECK" ]; then
    echo "✅ Verification token created: ${TOKEN_CHECK:0:30}..."
  else
    echo "⚠️  No token found in database"
  fi
  
  # Step 4: Check audit log
  echo ""
  echo "Step 4: Checking admin action audit log..."
  AUDIT_CHECK=$(docker exec hma_postgres psql -U hma_admin -d hma_academy -t -c \
    "SELECT action, reason, status FROM admin_action_audit_log WHERE user_id = '$USER_ID' ORDER BY created_at DESC LIMIT 1;")
  
  if [ -n "$AUDIT_CHECK" ]; then
    echo "✅ Audit log entry created:"
    echo "$AUDIT_CHECK"
  else
    echo "⚠️  No audit log entry found"
  fi
else
  echo "❌ Admin resend verification failed with HTTP $HTTP_CODE"
  
  if [ "$HTTP_CODE" == "400" ]; then
    echo ""
    echo "This is a validation error. Check the response details above."
  fi
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
