#!/bin/bash
BACKEND_URL="http://172.16.0.4:3001"

echo "Testing History Endpoint Fix"
echo "============================="
echo ""

# Login
echo "1. Logging in as admin..."
LOGIN_RESPONSE=$(curl -s -X POST $BACKEND_URL/api/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"info@huntmasteracademy.com","password":"Admin123!HMA"}')

ADMIN_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.tokens.accessToken')

if [ "$ADMIN_TOKEN" == "null" ] || [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ Login failed"
  exit 1
fi

echo "✅ Login successful"
echo ""

# Get first template
echo "2. Getting template ID..."
LIST_RESPONSE=$(curl -s -X GET $BACKEND_URL/api/admin/email-templates \
  -H "Authorization: Bearer $ADMIN_TOKEN")

TEMPLATE_ID=$(echo "$LIST_RESPONSE" | jq -r '.templates[0].id')
TEMPLATE_NAME=$(echo "$LIST_RESPONSE" | jq -r '.templates[0].name')

echo "Template: $TEMPLATE_NAME"
echo "ID: $TEMPLATE_ID"
echo ""

# Test history endpoint
echo "3. Testing history endpoint..."
HISTORY_RESPONSE=$(curl -s -X GET $BACKEND_URL/api/admin/email-templates/$TEMPLATE_ID/history \
  -H "Authorization: Bearer $ADMIN_TOKEN")

HISTORY_SUCCESS=$(echo "$HISTORY_RESPONSE" | jq -r '.success')
HISTORY_COUNT=$(echo "$HISTORY_RESPONSE" | jq -r '.count')

if [ "$HISTORY_SUCCESS" == "true" ]; then
  echo "✅ History endpoint working!"
  echo "History entries: $HISTORY_COUNT"
  
  if [ "$HISTORY_COUNT" != "0" ] && [ "$HISTORY_COUNT" != "null" ]; then
    echo ""
    echo "Sample history entry:"
    echo "$HISTORY_RESPONSE" | jq -r '.history[0] | "  Changed at: \(.changed_at)\n  Changed by: \(.changed_by_name) (\(.changed_by_email))\n  Note: \(.change_note)"'
  fi
else
  echo "❌ History endpoint failed"
  echo "Error: $(echo "$HISTORY_RESPONSE" | jq -r '.message')"
fi
