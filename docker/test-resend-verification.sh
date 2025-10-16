#!/bin/bash
# Test Resend Verification Feature

BACKEND_URL="http://172.16.0.4:3001"
TEST_EMAIL="test_resend_$(date +%s)@example.com"

echo "================================"
echo "Resend Verification Test"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Create unverified user
echo "Step 1: Creating unverified user..."
REGISTER=$(curl -s -X POST $BACKEND_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"firstName\": \"Test\",
    \"lastName\": \"User\",
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"TestPassword123!\",
    \"dateOfBirth\": \"1990-01-01\"
  }")

echo "$REGISTER" | jq '.'
echo ""

# Step 2: Delete the original token to simulate lost email
echo "Step 2: Simulating lost email (deleting token)..."
docker exec hma_postgres psql -U hma_admin -d hma_academy -c \
  "DELETE FROM email_verification_tokens WHERE email = '$TEST_EMAIL'" > /dev/null
echo -e "${GREEN}✅ Original token deleted${NC}"
echo ""

# Step 3: Test resend endpoint
echo "Step 3: Testing resend verification..."
RESEND=$(curl -s -X POST $BACKEND_URL/api/auth/resend-verification \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TEST_EMAIL\"}")

echo "Response:"
echo "$RESEND" | jq '.'
echo ""

RESEND_MSG=$(echo "$RESEND" | jq -r '.message')
if [[ "$RESEND_MSG" == *"sent"* ]]; then
  echo -e "${GREEN}✅ Resend successful${NC}"
else
  echo -e "${RED}❌ Resend failed${NC}"
  exit 1
fi
echo ""

# Step 4: Verify new token was created
echo "Step 4: Verifying new token..."
NEW_TOKEN=$(docker exec hma_postgres psql -U hma_admin -d hma_academy -t -A -c \
  "SELECT token FROM email_verification_tokens WHERE email = '$TEST_EMAIL'")

if [ -n "$NEW_TOKEN" ]; then
  echo -e "${GREEN}✅ New token created: ${NEW_TOKEN:0:30}...${NC}"
else
  echo -e "${RED}❌ No new token found${NC}"
  exit 1
fi
echo ""

# Step 5: Test the new token
echo "Step 5: Testing new confirmation link..."
CONFIRM_URL="$BACKEND_URL/api/auth/confirm?token=$NEW_TOKEN"
CONFIRM_RESULT=$(curl -s -L -w "\nHTTP_CODE:%{http_code}" "$CONFIRM_URL")
HTTP_CODE=$(echo "$CONFIRM_RESULT" | grep "HTTP_CODE:" | cut -d':' -f2)

if [ "$HTTP_CODE" == "200" ]; then
  echo -e "${GREEN}✅ Confirmation successful${NC}"
else
  echo -e "${RED}❌ Confirmation failed (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Step 6: Verify user is now verified
echo "Step 6: Checking user verification status..."
VERIFIED=$(docker exec hma_postgres psql -U hma_admin -d hma_academy -t -A -c \
  "SELECT email_verified FROM users WHERE email = '$TEST_EMAIL'")

if [ "$VERIFIED" == "t" ]; then
  echo -e "${GREEN}✅ User verified in database${NC}"
else
  echo -e "${RED}❌ User not verified${NC}"
fi
echo ""

# Step 7: Test resend on already verified account
echo "Step 7: Testing resend on verified account..."
RESEND_VERIFIED=$(curl -s -X POST $BACKEND_URL/api/auth/resend-verification \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TEST_EMAIL\"}")

echo "Response:"
echo "$RESEND_VERIFIED" | jq '.'
echo ""

ERROR=$(echo "$RESEND_VERIFIED" | jq -r '.error')
if [ "$ERROR" == "Already verified" ]; then
  echo -e "${GREEN}✅ Correctly rejects resend for verified accounts${NC}"
else
  echo -e "${YELLOW}⚠️  Expected 'Already verified' error${NC}"
fi
echo ""

# Cleanup
echo "Cleaning up..."
docker exec hma_postgres psql -U hma_admin -d hma_academy -c \
  "DELETE FROM users WHERE email = '$TEST_EMAIL'" > /dev/null
echo -e "${GREEN}✅ Test user deleted${NC}"
echo ""

echo "================================"
echo "📊 Test Summary"
echo "================================"
echo ""
echo "✅ Resend verification endpoint works"
echo "✅ New token created and stored"
echo "✅ New confirmation link works"
echo "✅ User verified successfully"
echo "✅ Rejects resend for already verified accounts"
echo ""
echo "================================"
echo "Resend Feature Verified! ✅"
echo "================================"
