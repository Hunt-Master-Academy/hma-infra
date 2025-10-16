#!/bin/bash
# Test Signup and Email Confirmation Flow

set -e

BACKEND_URL="http://172.16.0.4:3001"
FRONTEND_URL="http://localhost:3004"
TEST_EMAIL="test_user_$(date +%s)@example.com"
TEST_PASSWORD="TestPassword123!"

echo "================================"
echo "Signup & Email Confirmation Test"
echo "================================"
echo ""
echo "Test Email: $TEST_EMAIL"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# ISSUE 1: Test Registration Response (Email Should Be Returned)
# ============================================================================
echo "📝 Issue 1: Testing Registration Response"
echo "-----------------------------------"
REGISTER_RESPONSE=$(curl -s -X POST $BACKEND_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"firstName\": \"Test\",
    \"lastName\": \"User\",
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\",
    \"dateOfBirth\": \"1990-01-01\"
  }")

echo "Registration Response:"
echo "$REGISTER_RESPONSE" | jq '.'
echo ""

# Check if email is in response
EMAIL_IN_RESPONSE=$(echo "$REGISTER_RESPONSE" | jq -r '.email')
if [ "$EMAIL_IN_RESPONSE" == "$TEST_EMAIL" ]; then
  echo -e "${GREEN}✅ Email returned in registration response${NC}"
else
  echo -e "${RED}❌ Email NOT returned in registration response${NC}"
  echo "Expected: $TEST_EMAIL"
  echo "Got: $EMAIL_IN_RESPONSE"
fi
echo ""

# ============================================================================
# ISSUE 2: Test Email Confirmation Token
# ============================================================================
echo "🔐 Issue 2: Testing Email Confirmation Token"
echo "-----------------------------------"

# Get the confirmation token from database
echo "Fetching confirmation token from database..."
TOKEN_QUERY="SELECT token, expires_at, email FROM email_verification_tokens WHERE email = '$TEST_EMAIL'"
TOKEN_RESULT=$(docker exec hma_postgres psql -U hma_admin -d hma_academy -t -A -c "$TOKEN_QUERY")

if [ -z "$TOKEN_RESULT" ]; then
  echo -e "${RED}❌ No confirmation token found in database${NC}"
  echo "This means the email verification token was not created during registration."
  exit 1
fi

CONFIRMATION_TOKEN=$(echo "$TOKEN_RESULT" | cut -d'|' -f1)
TOKEN_EMAIL=$(echo "$TOKEN_RESULT" | cut -d'|' -f3)

echo -e "${GREEN}✅ Confirmation token found in database${NC}"
echo "Token: ${CONFIRMATION_TOKEN:0:20}..."
echo "Email: $TOKEN_EMAIL"
echo ""

# Test the confirmation endpoint
echo "Testing confirmation endpoint..."
CONFIRM_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BACKEND_URL/api/auth/confirm?token=$CONFIRMATION_TOKEN" \
  --max-redirs 0 \
  -L)

HTTP_CODE=$(echo "$CONFIRM_RESPONSE" | tail -n1)
CONFIRM_BODY=$(echo "$CONFIRM_RESPONSE" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "Response: $CONFIRM_BODY"
echo ""

if [ "$HTTP_CODE" == "302" ] || [ "$HTTP_CODE" == "200" ]; then
  echo -e "${GREEN}✅ Confirmation endpoint responded successfully${NC}"
  
  # Check if user is now verified
  USER_VERIFIED=$(docker exec hma_postgres psql -U hma_admin -d hma_academy -t -A -c \
    "SELECT email_verified FROM users WHERE email = '$TEST_EMAIL'")
  
  if [ "$USER_VERIFIED" == "t" ]; then
    echo -e "${GREEN}✅ User email verified in database${NC}"
  else
    echo -e "${RED}❌ User email NOT verified in database${NC}"
  fi
else
  echo -e "${RED}❌ Confirmation endpoint failed${NC}"
fi
echo ""

# ============================================================================
# ISSUE 3: Test Frontend Confirmation Flow
# ============================================================================
echo "🌐 Issue 3: Testing Frontend Confirmation Flow"
echo "-----------------------------------"

# The frontend expects /api/auth/confirm (proxied through Vite)
# ConfirmEmailPage.tsx makes request to: /api/auth/confirm?token=...
echo "Frontend confirmation URL: $FRONTEND_URL/confirm-email?token=$CONFIRMATION_TOKEN"
echo ""
echo -e "${YELLOW}ℹ️  Frontend Flow:${NC}"
echo "1. User clicks link in email: $BACKEND_URL/api/auth/confirm?token=..."
echo "2. Backend processes token at GET /api/auth/confirm"
echo "3. Backend redirects to: /email-confirmation (frontend route)"
echo "4. Frontend shows success/error page"
echo ""

# Test the full flow
echo "Testing full redirect chain..."
FULL_FLOW=$(curl -s -L -w "\nFINAL_URL:%{url_effective}\nHTTP_CODE:%{http_code}" \
  "$BACKEND_URL/api/auth/confirm?token=$CONFIRMATION_TOKEN")

FINAL_URL=$(echo "$FULL_FLOW" | grep "FINAL_URL:" | cut -d':' -f2-)
FINAL_CODE=$(echo "$FULL_FLOW" | grep "HTTP_CODE:" | cut -d':' -f2)

echo "Final URL: $FINAL_URL"
echo "Final HTTP Code: $FINAL_CODE"
echo ""

if [[ "$FINAL_URL" == *"/email-confirmation"* ]]; then
  echo -e "${GREEN}✅ Redirect to /email-confirmation page working${NC}"
else
  echo -e "${RED}❌ Did not redirect to /email-confirmation page${NC}"
  echo "Expected URL to contain: /email-confirmation"
  echo "Got: $FINAL_URL"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "================================"
echo "📊 Test Summary"
echo "================================"
echo ""
echo "Issue 1: Email in Registration Response"
if [ "$EMAIL_IN_RESPONSE" == "$TEST_EMAIL" ]; then
  echo -e "  ${GREEN}✅ PASS${NC} - Email is returned in response"
  echo "  Frontend can use this to display on thank you page"
else
  echo -e "  ${RED}❌ FAIL${NC} - Email is NOT returned in response"
  echo "  Frontend cannot display email on thank you page"
  echo ""
  echo "  🔧 Fix Required:"
  echo "  The registration endpoint needs to return the email in the response."
  echo "  Current response: $(echo "$REGISTER_RESPONSE" | jq -c '.')"
fi
echo ""

echo "Issue 2: Email Confirmation Link"
if [ "$HTTP_CODE" == "302" ] || [ "$HTTP_CODE" == "200" ]; then
  echo -e "  ${GREEN}✅ PASS${NC} - Confirmation endpoint working"
  echo "  User can click email link to verify account"
else
  echo -e "  ${RED}❌ FAIL${NC} - Confirmation endpoint not working"
  echo "  User cannot verify their email"
fi
echo ""

echo "Frontend Integration:"
echo "  Registration Success Page: $FRONTEND_URL/registration-success"
echo "  Email Confirmation Page: $FRONTEND_URL/email-confirmation"
echo ""
echo "  The frontend RegistrationSuccessPage expects:"
echo "  • sessionStorage.getItem('registration_email') to display email"
echo "  • SignupPage.tsx sets this from API response: data.email"
echo ""

# Cleanup
echo "🧹 Cleaning up test user..."
docker exec hma_postgres psql -U hma_admin -d hma_academy -c \
  "DELETE FROM users WHERE email = '$TEST_EMAIL'" > /dev/null

echo -e "${GREEN}✅ Test user deleted${NC}"
echo ""
echo "================================"
echo "Test Complete"
echo "================================"
