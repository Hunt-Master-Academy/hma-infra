#!/bin/bash
# Test Email Templates API Endpoint

echo "================================"
echo "Email Templates API Test"
echo "================================"
echo ""

# First, get admin auth token
echo "1. Logging in as admin..."
LOGIN_RESPONSE=$(curl -s -X POST http://172.16.0.4:3001/api/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "info@huntmasteracademy.com",
    "password": "Admin123!HMA"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.tokens.accessToken')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Login failed!"
  echo "Response: $LOGIN_RESPONSE"
  exit 1
fi

echo "✅ Login successful!"
echo ""

# Test email templates endpoint
echo "2. Fetching email templates..."
TEMPLATES_RESPONSE=$(curl -s -X GET http://172.16.0.4:3001/api/admin/email-templates \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Check if response contains success
if echo "$TEMPLATES_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
  TEMPLATE_COUNT=$(echo "$TEMPLATES_RESPONSE" | jq -r '.count')
  echo "✅ Email templates loaded successfully!"
  echo "   Found $TEMPLATE_COUNT templates"
  echo ""
  echo "3. Template list:"
  echo "$TEMPLATES_RESPONSE" | jq -r '.templates[] | "   - \(.name) (\(.template_key)) - \(if .is_active then "Active" else "Inactive" end)"'
else
  echo "❌ Failed to load email templates!"
  echo "Response: $TEMPLATES_RESPONSE"
  exit 1
fi

echo ""
echo "================================"
echo "✅ All tests passed!"
echo "================================"
