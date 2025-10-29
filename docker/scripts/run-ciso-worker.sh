#!/bin/bash
# CISO Assistant Worker Startup Script
# Waits for PostgreSQL then starts Huey worker

set -e

echo "Waiting for PostgreSQL..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if poetry run python -c "
import psycopg2
import sys
try:
    conn = psycopg2.connect(
        host='$DB_HOST',
        port='$POSTGRES_PORT',
        database='$POSTGRES_NAME',
        user='$POSTGRES_USER',
        password='$POSTGRES_PASSWORD',
        connect_timeout=3
    )
    conn.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
        echo "PostgreSQL is ready!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo "PostgreSQL not ready (attempt $attempt/$max_attempts), waiting..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "ERROR: PostgreSQL did not become ready in time"
    exit 1
fi

echo "Installing evidence collectors..."
if [ -d "/app/tasks/collectors" ]; then
    # Create tasks directory if it doesn't exist
    mkdir -p /code/tasks
    
    # Copy collectors into Django app
    cp -r /app/tasks/collectors /code/tasks/ 2>/dev/null || {
        echo "Warning: Could not copy collectors, they may already be installed"
    }
    
    # Create __init__.py if it doesn't exist
    touch /code/tasks/__init__.py 2>/dev/null || true
    
    echo "Evidence collectors installed"
else
    echo "No collectors directory found, skipping..."
fi

echo "Starting Huey worker..."
exec poetry run python manage.py run_huey
