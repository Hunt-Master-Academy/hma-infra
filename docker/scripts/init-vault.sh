#!/bin/bash
# Initialize HashiCorp Vault for HMA
# Creates secret paths and migrates secrets from .env

set -e

export VAULT_ADDR='http://vault:8200'
export VAULT_TOKEN="${VAULT_TOKEN:-hma_dev_root_token}"

echo "🚀 Initializing Vault for HMA..."
echo ""

# Wait for Vault to be ready
echo "⏳ Waiting for Vault to be ready..."
timeout=60
elapsed=0
while ! vault status > /dev/null 2>&1; do
    if [ $elapsed -ge $timeout ]; then
        echo "❌ Timeout waiting for Vault to be ready"
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
done
echo ""
echo "✅ Vault is ready!"
echo ""

# Enable KV v2 secrets engine at secret/ path (usually already enabled in dev mode)
echo "📦 Enabling KV v2 secrets engine..."
if vault secrets list | grep -q "^secret/"; then
    echo "   ✅ KV v2 engine already enabled at secret/"
else
    vault secrets enable -version=2 -path=secret kv
    echo "   ✅ KV v2 engine enabled at secret/"
fi
echo ""

# Create secret paths for HMA services
echo "🔐 Creating secret structure..."
echo ""

# Database credentials
echo "📝 Creating database secrets..."
vault kv put secret/hma/database \
  host=postgres \
  port=5432 \
  database=hma_academy \
  username=hma_admin \
  password="${DB_PASSWORD:-development_password}" \
  ssl=false
echo "   ✅ Database secrets created"

# Redis credentials
echo "📝 Creating Redis secrets..."
vault kv put secret/hma/redis \
  host=redis \
  port=6379 \
  password="${REDIS_PASSWORD:-development_redis}"
echo "   ✅ Redis secrets created"

# MinIO credentials
echo "📝 Creating MinIO secrets..."
vault kv put secret/hma/minio \
  endpoint=minio \
  port=9000 \
  access_key="${MINIO_USER:-minioadmin}" \
  secret_key="${MINIO_PASSWORD:-minioadmin}" \
  use_ssl=false
echo "   ✅ MinIO secrets created"

# JWT secrets
echo "📝 Creating JWT secrets..."
vault kv put secret/hma/jwt \
  secret="${JWT_SECRET:-your-secret-key-min-32-characters-long}" \
  issuer="hma-academy" \
  audience="hma-users" \
  expiration="24h"
echo "   ✅ JWT secrets created"

# Stripe API keys (placeholder - update with real keys)
echo "📝 Creating Stripe secrets..."
vault kv put secret/hma/stripe \
  secret_key="${STRIPE_SECRET_KEY:-sk_test_placeholder}" \
  public_key="${STRIPE_PUBLIC_KEY:-pk_test_placeholder}" \
  webhook_secret="${STRIPE_WEBHOOK_SECRET:-whsec_placeholder}"
echo "   ✅ Stripe secrets created"

# Email/SMTP credentials
echo "📝 Creating email secrets..."
vault kv put secret/hma/email \
  smtp_host="${SMTP_HOST:-smtp.hostinger.com}" \
  smtp_port="${SMTP_PORT:-587}" \
  smtp_user="${SMTP_USER:-info@huntmasteracademy.com}" \
  smtp_password="${SMTP_PASSWORD:-placeholder}" \
  from_address="${EMAIL_FROM:-info@huntmasteracademy.com}"
echo "   ✅ Email secrets created"

# Admin credentials
echo "📝 Creating admin secrets..."
vault kv put secret/hma/admin \
  email="${ADMIN_EMAIL:-tde8276@gmail.com}" \
  password_hash="placeholder_bcrypt_hash"
echo "   ✅ Admin secrets created"

# Redpanda credentials (if auth enabled)
echo "📝 Creating Redpanda secrets..."
vault kv put secret/hma/redpanda \
  brokers="redpanda:29092" \
  rest_proxy="http://redpanda:8082" \
  console_url="http://localhost:9091"
echo "   ✅ Redpanda secrets created"

# CISO Assistant credentials
echo "📝 Creating CISO Assistant secrets..."
vault kv put secret/hma/ciso \
  django_secret="${CISO_DJANGO_SECRET:-placeholder}" \
  db_password="${CISO_DB_PASSWORD:-placeholder}" \
  superuser_email="${CISO_SUPERUSER_EMAIL:-admin@huntmasteracademy.com}"
echo "   ✅ CISO Assistant secrets created"

echo ""
echo "📊 Secret Paths Created:"
vault kv list secret/hma/
echo ""

echo "🔍 Verify secrets:"
echo "   vault kv get secret/hma/database"
echo "   vault kv get -format=json secret/hma/database | jq -r .data.data"
echo ""

echo "✅ Vault initialization complete!"
echo ""
echo "🌐 Access Vault UI: http://localhost:8200"
echo "🔑 Dev Token: ${VAULT_TOKEN}"
echo ""
echo "📖 Next Steps:"
echo "   1. Update services to fetch secrets from Vault"
echo "   2. Enable audit logging: vault audit enable file file_path=/vault/logs/audit.log"
echo "   3. Setup dynamic database credentials for auto-rotation"
echo "   4. Configure secret rotation policies"
echo ""
