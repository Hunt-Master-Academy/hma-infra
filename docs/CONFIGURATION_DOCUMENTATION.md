# Hunt Master Academy - Configuration Documentation

## Complete Configuration Reference

This document provides comprehensive documentation for all configuration files, deployment settings, and service configurations in the Hunt Master Academy infrastructure.

---

## Configuration File Overview

### Primary Configuration Files
- **docker-compose.yml**: Service orchestration and container definitions
- **Service Dockerfiles**: Individual container build configurations
- **Application configs**: Service-specific configuration files
- **Database schemas**: Data structure definitions
- **Environment variables**: Runtime configuration parameters

---

## Docker Compose Configuration

### Complete docker-compose.yml Analysis

```yaml
# Hunt Master Academy Infrastructure
# Version: 1.0.0 (Alpha Testing Ready)
# Last Updated: September 12, 2025

version: '3.8'

services:
  # PostgreSQL Database Service
  postgres:
    image: postgres:15
    container_name: hma_postgres
    environment:
      POSTGRES_DB: huntmaster
      POSTGRES_USER: hma_admin
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U hma_admin -d huntmaster"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - hma_network

  # Redis Cache Service
  redis:
    image: redis:7-alpine
    container_name: hma_redis
    command: redis-server --requirepass development_password
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    networks:
      - hma_network

  # MinIO Object Storage Service
  minio:
    image: minio/minio:latest
    container_name: hma_minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    networks:
      - hma_network

  # Content Bridge API Service
  content-bridge:
    build:
      context: ./services/content-bridge
      dockerfile: Dockerfile
    container_name: hma-content-bridge
    ports:
      - "8090:8090"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql://hma_admin:dev_password@postgres:5432/huntmaster
      - REDIS_URL=redis://:development_password@redis:6379/0
      - MINIO_ENDPOINT=minio:9000
      - MINIO_ACCESS_KEY=minioadmin
      - MINIO_SECRET_KEY=minioadmin
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8090"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - hma_network

  # ML Server API Service
  ml-server:
    build:
      context: ./services/ml-server
      dockerfile: Dockerfile
    container_name: hma-ml-server
    ports:
      - "8010:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql://hma_admin:dev_password@postgres:5432/huntmaster
      - REDIS_URL=redis://:development_password@redis:6379/0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - hma_network

  # Database Administration Interface
  adminer:
    image: adminer:latest
    container_name: hma_adminer
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - hma_network

  # Redis Administration Interface
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: hma_redis_commander
    environment:
      REDIS_HOSTS: local:redis:6379:0:development_password
    ports:
      - "8081:8081"
    depends_on:
      - redis
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8081"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - hma_network

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  minio_data:
    driver: local

networks:
  hma_network:
    driver: bridge
```

### Configuration Analysis

#### Service Dependencies
```mermaid
graph TD
    A[postgres] --> D[content-bridge]
    B[redis] --> D[content-bridge]
    C[minio] --> D[content-bridge]
    A[postgres] --> E[ml-server]
    B[redis] --> E[ml-server]
    A[postgres] --> F[adminer]
    B[redis] --> G[redis-commander]
```

#### Network Configuration
- **Network Name**: `hma_network`
- **Network Type**: Bridge driver (default Docker networking)
- **Service Discovery**: Services can communicate using container names
- **Port Mapping**: All services expose specific ports to localhost

#### Volume Configuration
- **postgres_data**: Persistent PostgreSQL data storage
- **redis_data**: Persistent Redis data storage (RDB snapshots)
- **minio_data**: Persistent object storage data
- **Volume Driver**: Local (suitable for development, requires NFS/distributed storage for production)

---

## Service Configuration Details

### Content Bridge API Configuration

#### Dockerfile Analysis
```dockerfile
# services/content-bridge/Dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Expose application port
EXPOSE 8090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8090 || exit 1

# Run the application
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8090"]
```

#### Environment Variables
- **DATABASE_URL**: PostgreSQL connection string
- **REDIS_URL**: Redis connection string with password
- **MINIO_ENDPOINT**: MinIO server endpoint
- **MINIO_ACCESS_KEY**: MinIO access credentials
- **MINIO_SECRET_KEY**: MinIO secret credentials

#### Key Dependencies (requirements.txt)
```
fastapi==0.104.1
uvicorn[standard]==0.24.0
psycopg2-binary==2.9.9
redis==5.0.1
boto3==1.34.1
pydantic==2.5.0
httpx==0.25.2
```

### ML Server API Configuration

#### Dockerfile Analysis
```dockerfile
# services/ml-server/Dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/

# Expose application port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000 || exit 1

# Run the application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### Environment Variables
- **DATABASE_URL**: PostgreSQL connection string
- **REDIS_URL**: Redis connection string with password

#### Key Dependencies (requirements.txt)
```
fastapi==0.104.1
uvicorn[standard]==0.24.0
psycopg2-binary==2.9.9
redis==5.0.1
numpy==1.25.2
pydantic==2.5.0
```

---

## Database Configuration

### PostgreSQL Setup

#### Database Schema Structure
```sql
-- Hunt Master Academy Database Schema
-- Database: huntmaster
-- Version: 1.0.0

-- Core schema for application data
CREATE SCHEMA IF NOT EXISTS hma_core;

-- Content management schema
CREATE SCHEMA IF NOT EXISTS hma_content;

-- Machine learning schema
CREATE SCHEMA IF NOT EXISTS hma_ml;

-- User management schema
CREATE SCHEMA IF NOT EXISTS hma_users;

-- Example table structures (these would be created by applications)
-- Users table
CREATE TABLE IF NOT EXISTS hma_users.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Content table
CREATE TABLE IF NOT EXISTS hma_content.content_items (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    content_data JSONB,
    author_id INTEGER REFERENCES hma_users.users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ML models table
CREATE TABLE IF NOT EXISTS hma_ml.models (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(255) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    model_metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);
```

#### Connection Parameters
- **Host**: localhost (from host machine) / postgres (from containers)
- **Port**: 5432
- **Database**: huntmaster
- **Username**: hma_admin
- **Password**: dev_password (development only)
- **Connection Pool**: Managed by individual services

#### Performance Settings
```sql
-- PostgreSQL configuration optimizations for development
-- These would be in postgresql.conf for production

-- Memory settings
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB

-- Connection settings
max_connections = 100

-- Logging settings
log_statement = 'all'  -- For development debugging
log_duration = on
```

### Redis Configuration

#### Redis Settings
```redis
# Redis configuration for development
# In production, these would be in redis.conf

# Memory settings
maxmemory 512mb
maxmemory-policy allkeys-lru

# Persistence settings
save 900 1    # Save after 900 sec if at least 1 key changed
save 300 10   # Save after 300 sec if at least 10 keys changed
save 60 10000 # Save after 60 sec if at least 10000 keys changed

# Security
requirepass development_password

# Networking
bind 0.0.0.0
port 6379

# Database settings
databases 16
```

#### Cache Usage Patterns
```python
# Example cache key patterns used by services

# User sessions
user_session:{user_id} = {session_data}  # TTL: 3600s

# Content cache
content:{content_id} = {content_data}  # TTL: 1800s

# ML model cache
ml_model:{model_id} = {model_data}  # TTL: 7200s

# API rate limiting
rate_limit:{ip_address}:{endpoint} = {request_count}  # TTL: 60s
```

### MinIO Configuration

#### Bucket Structure
```
huntmaster-storage/
├── content/
│   ├── images/
│   ├── videos/
│   ├── documents/
│   └── curriculum/
├── ml-models/
│   ├── trained/
│   ├── artifacts/
│   └── datasets/
├── user-uploads/
│   ├── profiles/
│   └── submissions/
└── system/
    ├── logs/
    └── backups/
```

#### Access Policies
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::huntmaster-storage/content/*"]
    },
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": ["arn:aws:s3:::huntmaster-storage/user-uploads/*"]
    }
  ]
}
```

---

## Environment Configuration

### Development Environment Variables

#### Required Environment Variables
```bash
# Database Configuration
DATABASE_URL=postgresql://hma_admin:dev_password@localhost:5432/huntmaster

# Redis Configuration
REDIS_URL=redis://:development_password@localhost:6379/0

# MinIO Configuration
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false

# Application Configuration
ENV=development
DEBUG=true
LOG_LEVEL=INFO

# API Configuration
CONTENT_BRIDGE_URL=http://localhost:8090
ML_SERVER_URL=http://localhost:8010

# Security Configuration (development only)
SECRET_KEY=development-secret-key-change-in-production
JWT_SECRET=jwt-secret-key-change-in-production
```

#### Optional Environment Variables
```bash
# Performance Configuration
MAX_CONNECTIONS=100
CONNECTION_TIMEOUT=30
POOL_SIZE=10

# Feature Flags
ENABLE_AUTHENTICATION=true
ENABLE_RATE_LIMITING=true
ENABLE_CACHING=true

# Monitoring Configuration
ENABLE_METRICS=false
METRICS_PORT=9090
```

### Production Environment Considerations

#### Security Environment Variables (Production)
```bash
# Database Configuration (Production)
DATABASE_URL=postgresql://secure_user:${SECURE_PASSWORD}@prod-db:5432/huntmaster_prod
DATABASE_SSL_MODE=require

# Redis Configuration (Production)
REDIS_URL=redis://:${REDIS_PASSWORD}@prod-redis:6379/0
REDIS_SSL=true

# MinIO Configuration (Production)
MINIO_ENDPOINT=prod-storage.company.com
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
MINIO_SECURE=true

# Application Configuration (Production)
ENV=production
DEBUG=false
LOG_LEVEL=WARNING

# Security Configuration (Production)
SECRET_KEY=${SECRET_KEY}
JWT_SECRET=${JWT_SECRET}
CORS_ORIGINS=https://huntmaster.academy,https://app.huntmaster.academy
```

---

## Deployment Configuration

### Docker Compose Deployment Variations

#### Development (Current)
```yaml
# Development configuration (current docker-compose.yml)
# - Uses build context for services
# - Exposes all ports for debugging
# - Uses simple passwords
# - Includes admin interfaces
```

#### Staging Configuration
```yaml
# docker-compose.staging.yml
version: '3.8'

services:
  content-bridge:
    image: hma/content-bridge:staging
    environment:
      - ENV=staging
      - DATABASE_URL=${STAGING_DATABASE_URL}
    ports:
      - "8090:8090"
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
```

#### Production Configuration
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  content-bridge:
    image: hma/content-bridge:${VERSION}
    environment:
      - ENV=production
      - DATABASE_URL=${PROD_DATABASE_URL}
    ports:
      - "8090:8090"
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 30s
      restart_policy:
        condition: on-failure
        max_attempts: 3
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8090/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### Kubernetes Configuration (Future)

#### Basic Deployment Example
```yaml
# k8s/content-bridge-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: content-bridge
spec:
  replicas: 3
  selector:
    matchLabels:
      app: content-bridge
  template:
    metadata:
      labels:
        app: content-bridge
    spec:
      containers:
      - name: content-bridge
        image: hma/content-bridge:latest
        ports:
        - containerPort: 8090
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

---

## Configuration Management

### Configuration File Hierarchy

```
hma-infra/
├── docker-compose.yml                 # Main development configuration
├── docker-compose.staging.yml         # Staging environment
├── docker-compose.prod.yml           # Production environment
├── .env                              # Environment variables (local)
├── .env.example                      # Environment template
├── services/
│   ├── content-bridge/
│   │   ├── Dockerfile                # Container build config
│   │   ├── requirements.txt          # Python dependencies
│   │   └── config.py                 # Application configuration
│   └── ml-server/
│       ├── Dockerfile                # Container build config
│       ├── requirements.txt          # Python dependencies
│       └── src/config.py            # Application configuration
└── config/
    ├── postgres/
    │   ├── init.sql                  # Database initialization
    │   └── postgresql.conf           # Database configuration
    ├── redis/
    │   └── redis.conf               # Redis configuration
    └── nginx/                        # Future load balancer config
        └── nginx.conf
```

### Configuration Validation

#### Docker Compose Validation
```bash
# Validate docker-compose.yml syntax
docker-compose config

# Validate services can be built
docker-compose build --no-cache

# Validate service dependencies
docker-compose up --dry-run
```

#### Environment Validation
```python
# Example configuration validation script
import os
import sys

REQUIRED_VARS = [
    'DATABASE_URL',
    'REDIS_URL',
    'MINIO_ENDPOINT',
    'MINIO_ACCESS_KEY',
    'MINIO_SECRET_KEY'
]

def validate_environment():
    missing_vars = []
    for var in REQUIRED_VARS:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print(f"Missing required environment variables: {missing_vars}")
        sys.exit(1)
    
    print("Environment validation passed!")

if __name__ == "__main__":
    validate_environment()
```

---

## Security Configuration

### Development Security Settings

#### Current Security Measures
- **Database**: Basic username/password authentication
- **Redis**: Password protection enabled
- **MinIO**: Default admin credentials (development only)
- **APIs**: No authentication (stub implementation)
- **Network**: Bridge network isolation between containers

#### Security Improvements for Production
```yaml
# Enhanced security configuration for production

# Database Security
postgres:
  environment:
    POSTGRES_DB: ${DB_NAME}
    POSTGRES_USER: ${DB_USER}
    POSTGRES_PASSWORD: ${DB_PASSWORD}
    POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256"
  volumes:
    - ./config/postgres/pg_hba.conf:/etc/postgresql/pg_hba.conf
    - ./config/postgres/postgresql.conf:/etc/postgresql/postgresql.conf

# Redis Security
redis:
  command: >
    redis-server
    --requirepass ${REDIS_PASSWORD}
    --user default off
    --user app_user on >${APP_USER_PASSWORD} allcommands ~*
    --save ""
    --appendonly yes

# MinIO Security
minio:
  environment:
    MINIO_ROOT_USER: ${MINIO_ROOT_USER}
    MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    MINIO_SERVER_SIDE_ENCRYPTION: "on"
    MINIO_SSL_CERT_FILE: /certs/public.crt
    MINIO_SSL_KEY_FILE: /certs/private.key
```

### Network Security

#### Current Network Configuration
```yaml
networks:
  hma_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

#### Enhanced Network Security (Production)
```yaml
networks:
  frontend:
    driver: bridge
    internal: false
  backend:
    driver: bridge
    internal: true
  database:
    driver: bridge
    internal: true
```

---

## Performance Configuration

### Resource Allocation

#### Development Resource Limits
```yaml
# Current development configuration (no limits)
services:
  content-bridge:
    # No resource limits for development ease
```

#### Production Resource Limits
```yaml
# Production resource configuration
services:
  content-bridge:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
  
  ml-server:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

### Database Performance

#### PostgreSQL Performance Tuning
```sql
-- Production PostgreSQL configuration
-- postgresql.conf settings

# Memory settings
shared_buffers = 2GB
effective_cache_size = 6GB
work_mem = 64MB
maintenance_work_mem = 512MB

# Checkpoint settings
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Connection settings
max_connections = 200
```

### Redis Performance

#### Redis Memory Optimization
```redis
# Redis performance configuration
maxmemory 2gb
maxmemory-policy allkeys-lru

# Persistence optimization
save 3600 1
save 300 100
save 60 10000

# Network optimization
tcp-keepalive 300
timeout 0
```

---

## Configuration Updates and Migrations

### Version Control for Configurations

#### Configuration Versioning Strategy
```bash
# Tag configuration versions
git tag -a config-v1.0.0 -m "Initial alpha configuration"
git tag -a config-v1.1.0 -m "Added production security settings"

# Branch configuration environments
git checkout -b config/staging
git checkout -b config/production
```

#### Configuration Migration Scripts
```bash
#!/bin/bash
# scripts/migrate-config.sh

set -e

CURRENT_VERSION=$1
TARGET_VERSION=$2

echo "Migrating configuration from $CURRENT_VERSION to $TARGET_VERSION"

case "$TARGET_VERSION" in
  "1.1.0")
    echo "Adding security enhancements..."
    # Update docker-compose.yml with security settings
    # Update environment variables
    ;;
  "1.2.0")
    echo "Adding performance optimizations..."
    # Update resource limits
    # Update database configuration
    ;;
esac

echo "Configuration migration completed"
```

---

## Configuration Summary

### Quick Reference

#### Service Ports
- **Content Bridge API**: 8090
- **ML Server API**: 8010 (mapped from 8000)
- **PostgreSQL**: 5432
- **Redis**: 6379
- **MinIO API**: 9000
- **MinIO Console**: 9001
- **Adminer**: 8080
- **Redis Commander**: 8081

#### Default Credentials (Development Only)
- **PostgreSQL**: `hma_admin` / `dev_password`
- **Redis**: Password: `development_password`
- **MinIO**: `minioadmin` / `minioadmin`

#### Key Configuration Files
- **docker-compose.yml**: Main orchestration
- **services/*/Dockerfile**: Container definitions
- **services/*/requirements.txt**: Dependencies
- **Environment variables**: Runtime configuration

---

## Configuration Warnings

### Development vs Production

**IMPORTANT**: The current configuration is optimized for development and testing. For production deployment:

1. **Change all default passwords**
2. **Enable SSL/TLS encryption**
3. **Implement proper authentication**
4. **Add resource limits**
5. **Enable logging and monitoring**
6. **Use secrets management**
7. **Implement backup strategies**

### Security Considerations

**CRITICAL**: Never use development credentials in production:
- Database passwords
- Redis passwords
- MinIO access keys
- API secrets
- JWT tokens

---

*This configuration documentation reflects the Hunt Master Academy infrastructure as of September 12, 2025. All configurations are ready for alpha testing and further development.*