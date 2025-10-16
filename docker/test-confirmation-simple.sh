#!/bin/bash
TEST_EMAIL="test_confirm_$(date +%s)@example.com"
BACKEND_URL="http://172.16.0.4:3001"

echo "Creating test user..."
RESPONSE=$(curl -s -X POST $BACKEND_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"firstName\": \"Test\",
    \"lastName\": \"User\",
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"TestPassword123!\",
    \"dateOfBirth\": \"1990-01-01\"
  }")

echo "Registration response:"
echo "$RESPONSE" | jq '.'
echo ""

# Get token
TOKEN=$(docker exec hma_postgres psql -U hma_admin -d hma_academy -t -A -c "SELECT token FROM email_verification_tokens WHERE email = '$TEST_EMAIL'")

echo "Confirmation token: ${TOKEN:0:30}..."
echo ""
echo "Testing confirmation endpoint..."

# Use simpler curl
CONFIRM_URL="$BACKEND_URL/api/auth/confirm?token=$TOKEN"
echo "URL: $CONFIRM_URL"
echo ""

curl -v "$CONFIRM_URL" 2>&1 | head -30

echo ""
echo "Checking if user is verified..."
VERIFIED=$(docker exec hma_postgres psql -U hma_admin -d hma_academy -t -A -c "SELECT email_verified FROM users WHERE email = '$TEST_EMAIL'")

if [ "$VERIFIED" == "t" ]; then
  echo "✅ User is verified"
else
  echo "❌ User is NOT verified (value: $VERIFIED)"
fi

# Cleanup
docker exec hma_postgres psql -U hma_admin -d hma_academy -c "DELETE FROM users WHERE email = '$TEST_EMAIL'" > /dev/null
echo "Test user deleted"
