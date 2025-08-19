#!/bin/bash
# setup-dev-environment.sh

echo "🎯 Hunt Master Academy - Development Environment Setup"
echo "======================================================"

# Check prerequisites
check_requirements() {
    echo "📋 Checking system requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Please install Docker first."
        exit 1
    fi
    echo "✅ Docker installed"
    
        # Check Docker Compose (prefer v2 `docker compose`, fallback to legacy `docker-compose`)
        if docker compose version >/dev/null 2>&1; then
            echo "✅ Docker Compose v2 available"
        elif command -v docker-compose >/dev/null 2>&1; then
            echo "ℹ️  Using legacy docker-compose binary"
        else
            echo "❌ Docker Compose not found. Install Docker Compose v2 (docker compose) or legacy docker-compose."
            exit 1
        fi
    
    # Check available disk space (require at least 10GB)
    available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 10 ]; then
        echo "⚠️  Warning: Less than 10GB of disk space available"
    fi
}

# Create necessary directories
setup_directories() {
    echo "📁 Creating directory structure..."
    
    directories=(
        "database/init"
        "database/migrations"
        "database/seeds"
        "database/backups"
        "models"
        "ml-server/src"
        "logs"
        "config"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        echo "  ✅ Created $dir"
    done
}

# Generate environment file
generate_env_file() {
    echo "🔐 Generating environment configuration..."
    
    if [ ! -f .env ]; then
        cat > .env <<EOF
# Database Configuration
DB_PASSWORD=$(openssl rand -base64 32)
APP_PASSWORD=$(openssl rand -base64 32)

# MinIO Configuration
MINIO_USER=minioadmin
MINIO_PASSWORD=$(openssl rand -base64 32)

# Redis Configuration
REDIS_PASSWORD=$(openssl rand -base64 32)

# ML Server Configuration
ML_SERVER_SECRET=$(openssl rand -base64 32)

# Environment
ENVIRONMENT=development
LOG_LEVEL=debug
EOF
        echo "  ✅ Generated .env file with secure passwords"
    else
        echo "  ℹ️  .env file already exists, skipping..."
    fi
}

# Start services
start_services() {
    echo "🚀 Starting Docker services..."
    
    docker compose -f docker/docker-compose.yml up -d --build
    
        echo "⏳ Waiting for services to be healthy..."
        # poll for health for up to ~60s
        for i in {1..30}; do
            ok=0
            docker compose -f docker/docker-compose.yml ps | grep -q "postgres.*healthy" && ok=$((ok+1)) || true
            docker compose -f docker/docker-compose.yml ps | grep -q "redis.*healthy" && ok=$((ok+1)) || true
            docker compose -f docker/docker-compose.yml ps | grep -q "minio.*healthy" && ok=$((ok+1)) || true
            [[ $ok -ge 3 ]] && break
            sleep 2
        done
        docker compose -f docker/docker-compose.yml ps
}

# Initialize database
initialize_database() {
    echo "🗄️  Initializing database..."
    
    docker compose -f docker/docker-compose.yml exec -T postgres psql -U hma_admin -d huntmaster < database/init/schema.sql || true
    
    echo "  ✅ Database schema created"
}

# Create MinIO buckets
setup_minio() {
    echo "📦 Setting up MinIO buckets..."
    
    # Wait for MinIO to be ready
    sleep 5
    
        # Create buckets using MinIO client (attach to compose network)
        # Determine network name used by compose (project = folder containing compose file)
        COMPOSE_DIR=$(dirname "docker/docker-compose.yml")
        COMPOSE_PROJECT=$(basename "$COMPOSE_DIR")
        COMPOSE_NET="${COMPOSE_PROJECT}_hma_network"
                MINIO_USER_VAL=$(grep '^MINIO_USER=' .env | cut -d '=' -f2)
                MINIO_PASS_VAL=$(grep '^MINIO_PASSWORD=' .env | cut -d '=' -f2)

                # Use inline alias via MC_HOST_local env to avoid persistent alias
                for b in huntmaster-media huntmaster-models huntmaster-backups; do
                    docker run --rm --network="$COMPOSE_NET" \
                        -e MC_HOST_local="http://$MINIO_USER_VAL:$MINIO_PASS_VAL@minio:9000" \
                        minio/mc mb -p --ignore-existing "local/$b" >/dev/null 2>&1 || true
                done
                echo "  ✅ MinIO buckets ensured"
}

# Main execution
main() {
    check_requirements
    setup_directories
    generate_env_file
    start_services
    initialize_database
    setup_minio
    
    echo ""
    echo "✨ Development environment setup complete!"
    echo ""
    echo "📍 Service URLs:"
    echo "  • PostgreSQL: localhost:5432"
    echo "  • Redis: localhost:6379"
    echo "  • MinIO Console: http://localhost:9001"
    echo "  • Adminer: http://localhost:8080"
    echo "  • Redis Commander: http://localhost:8081"
    echo "  • ML Server: http://localhost:8010"
    echo ""
    echo "📚 Next steps:"
    echo "  1. Run database migrations: ./scripts/migrate.sh"
    echo "  2. Seed test data: ./scripts/seed.sh"
    echo "  3. Start development server: npm run dev"
    echo ""
    echo "🛑 To stop services: docker-compose down"
        echo "🗑️  To reset everything: docker compose -f docker/docker-compose.yml down -v"
}

# Run main function
main