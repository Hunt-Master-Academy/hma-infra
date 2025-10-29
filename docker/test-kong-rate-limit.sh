#!/bin/bash
# Test Kong Rate Limiting
# Tests rate limiting enforcement on API endpoints

set -e

echo "=== Kong Rate Limiting Test ==="
echo ""

# Generate JWT token
JWT_SECRET="dev-super-secret-jwt-key-change-in-production"
KEY_ID="hma-brain-jwt"
header=$(echo -n '{"alg":"HS256","typ":"JWT","kid":"'$KEY_ID'"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
exp=$(($(date +%s) + 3600))
payload=$(echo -n '{"sub":"test-user","exp":'$exp',"iss":"hma-academy"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
signature=$(echo -n "${header}.${payload}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
JWT="${header}.${payload}.${signature}"

echo "Making 5 rapid requests to test rate limiting..."
echo ""

for i in {1..5}; do
  response=$(curl -s -w "\nHTTP_CODE:%{http_code}\nRATE_LIMIT:%{header_x_ratelimit_limit_minute}\nRATE_REMAINING:%{header_x_ratelimit_remaining_minute}\n" \
    -H "Authorization: Bearer $JWT" \
    http://localhost:8010/health)
  
  http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d: -f2)
  rate_limit=$(echo "$response" | grep "RATE_LIMIT" | cut -d: -f2)
  rate_remaining=$(echo "$response" | grep "RATE_REMAINING" | cut -d: -f2)
  
  echo "Request $i: HTTP $http_code | Limit: $rate_limit/min | Remaining: $rate_remaining"
  
  if [ "$http_code" == "429" ]; then
    echo "  ⚠️  Rate limit exceeded!"
  fi
  
  sleep 0.2
done

echo ""
echo "=== Rate Limiting Headers Test Complete ==="
echo ""
echo "Configuration:"
echo "  - Free tier: 60 requests/minute"
echo "  - Basic tier: 120 requests/minute"
echo "  - Pro tier: 300 requests/minute"
echo "  - Elite/Enterprise: Unlimited"
