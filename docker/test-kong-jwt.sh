#!/bin/bash
# Test Kong JWT Authentication
# This script generates a JWT token and tests Kong authentication

set -e

echo "=== Kong JWT Authentication Test ==="
echo ""

# JWT Configuration
JWT_SECRET="dev-super-secret-jwt-key-change-in-production"
KEY_ID="hma-brain-jwt"

# Generate JWT header (HS256)
header=$(echo -n '{"alg":"HS256","typ":"JWT","kid":"'$KEY_ID'"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Generate JWT payload (expires in 1 hour)
exp=$(($(date +%s) + 3600))
payload=$(echo -n '{"sub":"test-user","exp":'$exp',"iss":"hma-academy"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Create signature
signature=$(echo -n "${header}.${payload}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Complete JWT
JWT="${header}.${payload}.${signature}"

echo "Generated JWT Token:"
echo "${JWT:0:50}..."
echo ""

echo "Testing unauthenticated request (should fail with 401):"
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:8010/api/admin/subscription-plans | head -5
echo ""

echo "Testing authenticated request with JWT token:"
curl -s -H "Authorization: Bearer $JWT" \
  -w "\nHTTP Status: %{http_code}\n" \
  http://localhost:8010/api/admin/subscription-plans | jq -r 'if type == "array" then "✅ Success! Received \(length) subscription plans" else . end'
echo ""

echo "=== Test Complete ==="
