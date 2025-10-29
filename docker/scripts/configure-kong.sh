#!/bin/bash
# Configure Kong API Gateway for HMA
# Creates services, routes, and plugins for Brain API

set -e

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"
BRAIN_SERVICE_URL="${BRAIN_SERVICE_URL:-http://hma-academy-brain:3001}"

echo "🚀 Configuring Kong API Gateway for HMA..."
echo ""

# Function to check if Kong is ready
check_kong_ready() {
    echo "⏳ Waiting for Kong Admin API to be ready..."
    timeout=60
    elapsed=0
    while ! curl -sf "${KONG_ADMIN_URL}" > /dev/null 2>&1; do
        if [ $elapsed -ge $timeout ]; then
            echo "❌ Timeout waiting for Kong to be ready"
            exit 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -n "."
    done
    echo ""
    echo "✅ Kong is ready!"
    echo ""
}

check_kong_ready

# 1. Create HMA Brain Service
echo "📝 Creating HMA Brain API service..."
BRAIN_SERVICE=$(curl -s -X POST "${KONG_ADMIN_URL}/services" \
  --data "name=hma-brain" \
  --data "url=${BRAIN_SERVICE_URL}" \
  --data "protocol=http" \
  --data "connect_timeout=60000" \
  --data "write_timeout=60000" \
  --data "read_timeout=60000")

BRAIN_SERVICE_ID=$(echo "$BRAIN_SERVICE" | jq -r '.id')
echo "   ✅ Service created: hma-brain (ID: ${BRAIN_SERVICE_ID})"
echo ""

# 2. Create routes for Brain API

# General API route
echo "📝 Creating route: /api/* → Brain API"
curl -s -X POST "${KONG_ADMIN_URL}/services/hma-brain/routes" \
  --data "name=brain-api" \
  --data "paths[]=/api" \
  --data "strip_path=false" \
  --data "preserve_host=false" > /dev/null
echo "   ✅ Route created: /api/*"

# Admin API route (higher priority)
echo "📝 Creating route: /api/admin/* → Brain Admin API"
curl -s -X POST "${KONG_ADMIN_URL}/services/hma-brain/routes" \
  --data "name=brain-admin-api" \
  --data "paths[]=/api/admin" \
  --data "strip_path=false" \
  --data "preserve_host=false" > /dev/null
echo "   ✅ Route created: /api/admin/*"

# Health check route (public)
echo "📝 Creating route: /health → Brain Health Check"
curl -s -X POST "${KONG_ADMIN_URL}/services/hma-brain/routes" \
  --data "name=brain-health" \
  --data "paths[]=/health" \
  --data "strip_path=false" \
  --data "preserve_host=false" > /dev/null
echo "   ✅ Route created: /health"

echo ""

# 3. Enable Prometheus plugin (global)
echo "📊 Enabling Prometheus metrics plugin..."
curl -s -X POST "${KONG_ADMIN_URL}/plugins" \
  --data "name=prometheus" > /dev/null
echo "   ✅ Prometheus plugin enabled (global)"
echo "   📍 Metrics available at: ${KONG_ADMIN_URL}/metrics"
echo ""

# 4. Enable request logging plugin
echo "📝 Enabling request logging plugin..."
curl -s -X POST "${KONG_ADMIN_URL}/services/hma-brain/plugins" \
  --data "name=http-log" \
  --data "config.http_endpoint=http://hma-academy-brain:3001/api/logs/kong" \
  --data "config.method=POST" \
  --data "config.timeout=10000" \
  --data "config.keepalive=60000" > /dev/null
echo "   ✅ HTTP logging plugin enabled"
echo ""

# 5. Enable CORS plugin
echo "🌐 Enabling CORS plugin..."
curl -s -X POST "${KONG_ADMIN_URL}/services/hma-brain/plugins" \
  --data "name=cors" \
  --data "config.origins=http://localhost:3004,http://172.16.0.4:3004" \
  --data "config.methods=GET,POST,PUT,DELETE,PATCH,OPTIONS" \
  --data "config.headers=Accept,Authorization,Content-Type,X-Requested-With" \
  --data "config.exposed_headers=X-Auth-Token" \
  --data "config.credentials=true" \
  --data "config.max_age=3600" > /dev/null
echo "   ✅ CORS plugin enabled"
echo ""

# 6. Enable rate limiting plugin (basic tier)
echo "⏱️  Enabling rate limiting plugin..."
curl -s -X POST "${KONG_ADMIN_URL}/services/hma-brain/plugins" \
  --data "name=rate-limiting" \
  --data "config.minute=60" \
  --data "config.hour=1000" \
  --data "config.policy=local" \
  --data "config.fault_tolerant=true" \
  --data "config.hide_client_headers=false" > /dev/null
echo "   ✅ Rate limiting enabled (60/min, 1000/hour)"
echo ""

# 7. Enable request/response transformer for headers
echo "🔧 Enabling request transformer plugin..."
curl -s -X POST "${KONG_ADMIN_URL}/services/hma-brain/plugins" \
  --data "name=request-transformer" \
  --data "config.add.headers=X-Kong-Gateway:true" \
  --data "config.add.headers=X-Request-Id:\$(request_id)" > /dev/null
echo "   ✅ Request transformer enabled"
echo ""

# 8. Summary
echo "📊 Configuration Summary:"
echo ""
echo "Services:"
curl -s "${KONG_ADMIN_URL}/services" | jq -r '.data[] | "  - \(.name): \(.protocol)://\(.host):\(.port)"'
echo ""

echo "Routes:"
curl -s "${KONG_ADMIN_URL}/routes" | jq -r '.data[] | "  - \(.name): \(.paths[])"'
echo ""

echo "Plugins:"
curl -s "${KONG_ADMIN_URL}/plugins" | jq -r '.data[] | "  - \(.name) (\(.enabled | if . then "enabled" else "disabled" end))"'
echo ""

echo "✅ Kong configuration complete!"
echo ""
echo "🧪 Test the gateway:"
echo "   curl http://localhost:8000/health"
echo "   curl http://localhost:8000/api/auth/login"
echo ""
echo "📊 View metrics:"
echo "   curl http://localhost:8001/metrics"
echo ""
echo "🌐 Access Konga UI:"
echo "   http://localhost:1337"
echo "   (Configure connection: Kong Admin URL = http://kong:8001)"
echo ""
