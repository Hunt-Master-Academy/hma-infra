# Hunt Master Academy - Infrastructure

🎯 Core infrastructure and database architecture for the Hunt Master Academy platform - a revolutionary AI-powered hunting education system.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Database Management](#database-management)
- [Services](#services)
- [Common Operations](#common-operations)
- [Compliance & Security](#compliance--security)
- [Performance & Scaling](#performance--scaling)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Related Repositories](#related-repositories)
- [Roadmaps & Workstreams](#roadmaps--workstreams)

## Overview

This repository contains the foundational infrastructure for Hunt Master Academy, including:

- **Database Architecture**: Complete PostgreSQL schema for all five educational pillars
- **ML Infrastructure**: Tables and services for AI/Computer Vision/AR integration
- **Development Environment**: Docker-based local development setup
- **Compliance Framework**: COPPA, GDPR, and state hunting regulation compliance
- **Performance Optimization**: Caching, indexing, and partitioning strategies

### Key Features

- 🔒 **Age-Gated Access**: 18+ requirement with comprehensive audit logging
- 🤖 **AI-Ready**: Pre-configured for ML model deployment and processing
- 🌐 **Cross-Platform**: Supports web, iOS, Android, and desktop clients
- 📊 **Analytics-Enabled**: Built-in metrics and performance tracking
- 🔄 **Offline-First**: Designed for field use without connectivity

## Prerequisites

### System Requirements

- **Docker**: Version 20.10+ with Docker Compose v2.0+
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Storage**: 20GB free space for development (200TB+ for production)
- **OS**: macOS, Linux, or Windows with WSL2

### Software Dependencies

```bash
# Check prerequisites
docker --version  # Should be 20.10+
docker-compose --version  # Should be 2.0+

# Optional but recommended
make --version  # For using Makefile commands
psql --version  # For direct database access
```

## Architecture

### Database Schema Overview

```
┌─────────────────────────────────────────────────┐
│                Core Schemas                      │
├───────────────────────────────────────────────────┤
│ • auth          - Authentication & compliance    │
│ • users         - User profiles & preferences    │
│ • content       - Educational content management │
│ • progress      - Learning progress tracking     │
└───────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│              Pillar Schemas                      │
├───────────────────────────────────────────────────┤
│ • game_calls         - Audio analysis & training │
│ • hunt_strategy      - Planning & predictive AI  │
│ • stealth_scouting   - Sign identification & CV  │
│ • tracking_recovery  - Blood trail & AR tracking │
│ • gear_marksmanship  - Ballistics & virtual range│
└───────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│           Infrastructure Schemas                 │
├───────────────────────────────────────────────────┤
│ • ml_infrastructure  - Model registry & jobs     │
│ • analytics          - Metrics & aggregations    │
│ • events             - Event sourcing & CQRS     │
└───────────────────────────────────────────────────┘
```

### Technology Stack

- **Database**: PostgreSQL 16 with PostGIS, pgvector
- **Cache**: Redis 7.2 with persistence
- **Object Storage**: MinIO (S3-compatible)
- **Time Series**: TimescaleDB extension
- **Search**: PostgreSQL full-text search (Elasticsearch ready)

## Layout

```
hma-infra/
├── docker/          # Docker Compose stacks and service configs
├── database/        # SQL schemas, migrations, seeds, triggers, functions
│   ├── schemas/     # Complete table definitions
│   ├── migrations/  # Versioned migration scripts
│   ├── seeds/       # Development and reference data
│   ├── triggers/    # Audit and validation triggers
│   └── functions/   # Stored procedures and functions
├── scripts/         # Helper scripts to manage local env and DB
├── terraform/       # IaC for cloud deployment
└── docs/           # Architecture documentation and runbooks
```

## Quick Start

### 1. Initial Setup

```bash
# Clone repository
git clone https://github.com/your-org/hma-infra.git
cd hma-infra

# Run automated setup (creates .env, starts services, initializes DB)
bash scripts/setup-dev-environment.sh

# Verify all services are healthy
docker compose -f docker/docker-compose.yml ps

### 1.1 Load Demo Data (optional)

To load sample users, content, progress, and ML models for local testing:

```bash
./scripts/seed.sh database/seeds/05_demo_data.sql
```

Verify data exists:

```bash
docker compose -f docker/docker-compose.yml exec -T postgres psql -U hma_admin -d huntmaster -c "
SELECT 'auth.users' AS table, COUNT(*) FROM auth.users;
SELECT 'users.profiles' AS table, COUNT(*) FROM users.profiles;
SELECT 'content.items' AS table, COUNT(*) FROM content.items;
SELECT 'progress.user_progress' AS table, COUNT(*) FROM progress.user_progress;
SELECT 'ml_infrastructure.model_registry' AS table, COUNT(*) FROM ml_infrastructure.model_registry;"
```
```

### 2. Environment Variables

The setup script generates a `.env` file with secure defaults. Key variables:

```bash
# Database
DB_PASSWORD=<auto-generated>
APP_PASSWORD=<auto-generated>

# Object Storage
MINIO_USER=minioadmin
MINIO_PASSWORD=<auto-generated>

# Caching
REDIS_PASSWORD=<auto-generated>

# ML Processing
ML_SERVER_SECRET=<auto-generated>

# Environment
ENVIRONMENT=development
LOG_LEVEL=debug
```

### 3. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| PostgreSQL | `localhost:5432` | DB: `huntmaster`, User: `hma_admin`, Pass: `.env` |
| Redis | `localhost:6379` | Password: from `.env` |
| MinIO Console | `http://localhost:9001` | User/Pass: from `.env` |
| Adminer | `http://localhost:8080` | Use PostgreSQL credentials |
| Redis Commander | `http://localhost:8081` | No auth in dev |
| ML Server | `http://localhost:8010` | API Key: from `.env` |
| Content Bridge | `http://localhost:8090` | N/A |

## Database Management

### Run Migrations

```bash
# Apply all pending migrations
./scripts/migrate.sh

# Rollback last migration
./scripts/migrate.sh rollback

# Check migration status
./scripts/migrate.sh status
```

### Seed Data

```bash
# Load all seed data
./scripts/seed.sh

# Load specific seed file
./scripts/seed.sh database/seeds/01_reference_data.sql

# Load demo data for dev
./scripts/seed.sh database/seeds/05_demo_data.sql

# Load test users (dev only)
./scripts/seed.sh --test-users
```

### Backup & Restore

```bash
# Create backup
./scripts/backup-database.sh

# Restore from backup
./scripts/restore-database.sh backups/backup_20250117_120000.sql

# Automated daily backups (production)
./scripts/setup-backups.sh
```

### Database Reset

```bash
# Complete reset (CAUTION: Destroys all data)
./scripts/reset-database.sh

# Reset specific schema
./scripts/reset-database.sh --schema game_calls
```

## Common Operations

### Container Management

```bash
# Start all services
docker compose -f docker/docker-compose.yml up -d

# Stop all services
docker compose -f docker/docker-compose.yml down

# View logs
docker compose -f docker/docker-compose.yml logs -f [service_name]

# Restart specific service
docker compose -f docker/docker-compose.yml restart postgres

# Clean everything (including volumes)
docker compose -f docker/docker-compose.yml down -v
```

### Database Access

```bash
# Connect via psql
docker compose -f docker/docker-compose.yml exec postgres psql -U hma_admin -d huntmaster

# Run SQL file
docker compose -f docker/docker-compose.yml exec -T postgres psql -U hma_admin -d huntmaster < your_script.sql

# Database shell via Adminer
# open http://localhost:8080
```

### Performance Monitoring

```bash
# Check database statistics
./scripts/db-stats.sh

# Monitor query performance
./scripts/slow-queries.sh

# Cache hit rates
./scripts/cache-stats.sh
```

## Compliance & Security

### Age Verification (COPPA)

- **Requirement**: All users must be 18+ years old
- **Implementation**: Age gate at registration with audit logging
- **Verification**: `auth.users.birth_date` with CHECK constraint

### Data Privacy (GDPR/CCPA)

- **Right to Access**: User data export via API
- **Right to Delete**: Soft delete with 30-day retention
- **Audit Trail**: Complete activity logging in `auth.audit_log`

### Hunting Regulations

- **Disclaimer**: Platform is educational only
- **State Compliance**: Users must verify local regulations
- **Legal Protection**: Terms acceptance tracked in database

### Security Features

- Row-Level Security (RLS) on sensitive tables
- Encrypted passwords with bcrypt
- JWT token rotation with refresh tokens
- API rate limiting configuration
- Comprehensive audit logging

## Performance & Scaling

### Expected Load

| Metric | Year 1 Target | Year 3 Target |
|--------|---------------|---------------|
| Daily Active Users | 25-50k peak | 100-250k peak |
| Concurrent Users | 5-7.5k | 15-30k |
| Storage (User Content) | 20-30 TB | 150-200 TB |
| API Requests/sec | 1,000 | 10,000 |

### Optimization Strategies

- **Indexing**: GIN indexes on JSONB, B-tree on foreign keys
- **Partitioning**: Monthly partitions for audit logs, events
- **Caching**: Redis with 5-minute TTL for hot data
- **CDN**: Static content and media files
- **Async Processing**: Job queues for ML workloads

## Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check Docker daemon
docker info

# Check port conflicts
lsof -i :5432  # PostgreSQL
lsof -i :6379  # Redis

# Reset and try again
docker-compose down -v
./scripts/setup-dev-environment.sh
```

#### Database Connection Failed
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Verify credentials
cat .env | grep DB_PASSWORD

# Test connection
docker-compose exec postgres pg_isready
```

#### Out of Disk Space
```bash
# Check Docker space usage
docker system df

# Clean unused resources
docker system prune -a

# Remove old backups
rm -rf database/backups/backup_*.sql
```

## Testing

```bash
# Run database tests
./scripts/test-database.sh

# Performance benchmarks
./scripts/benchmark.sh

# Load testing
./scripts/load-test.sh --users 1000 --duration 60s
```

## Contributing

1. Create feature branch: `git checkout -b feature/your-feature`
2. Make changes and test locally
3. Run migrations: `./scripts/migrate.sh`
4. Run tests: `./scripts/test-database.sh`
5. Commit with conventional commits: `feat:`, `fix:`, `docs:`, etc.
6. Push and create PR

### Coding Standards

- SQL: Follow [PostgreSQL style guide](https://www.postgresql.org/docs/current/sql-syntax.html)
- Use lowercase with underscores for tables/columns
- Add comments for complex queries
- Include indexes for foreign keys

## Related Repositories

| Repository | Purpose |
|------------|---------|
| [hma-academy-brain](../hma-academy-brain) | Academy orchestrator service |
| [hma-gamecalls-engine](../hma-gamecalls-engine) | Game calls processing engine |
| [hma-hunt-strategy-engine](../hma-hunt-strategy-engine) | Hunt strategy AI service |
| [hma-common-libs](../hma-common-libs) | Shared TypeScript types |
| [hma-deployment](../hma-deployment) | Production deployment configs |
| [hma-ai-models](../hma-ai-models) | Model artifacts, validation, benchmarks |
| [hma-content](../hma-content) | Curriculum/content and data policies |

## Monitoring & Observability

- **Metrics**: Prometheus endpoint at `:9090/metrics`
- **Logs**: Centralized in `/logs` directory
- **Tracing**: OpenTelemetry ready (not enabled by default)
- **Alerts**: Configure in `monitoring/alerts.yml`

## Current Status (Local Dev)

- Containers running: PostgreSQL (PostGIS), Redis, MinIO, Adminer, Redis Commander, ML Model Server
- Core schemas initialized: auth, users, content, progress, ml_infrastructure
- Demo data available: 2 users, 2 profiles, 2 content items, 2 progress rows, 2 ML models

## Content Bridge (Local Content Delivery)

Start content bridge and mount content repository:

```bash
./scripts/setup-content-dev.sh
```

API endpoints:

- Health: GET http://localhost:8090/health
- Audio: GET http://localhost:8090/api/audio/{category}/{species}/{filename}
- Icons: GET http://localhost:8090/api/icons/{category}/{name}
- Research: GET http://localhost:8090/api/research/{category}/{paper_id}
- Manifest: GET http://localhost:8090/api/manifest

Environment config example: `config/services/alpha.yaml`.

## Support

- **Documentation**: [docs/](./docs)
- **Issues**: [GitHub Issues](https://github.com/your-org/hma-infra/issues)
- **Slack**: #hma-infrastructure channel
- **Wiki**: [Internal Wiki](https://wiki.your-org.com/hma)

## For AI assistants

- See `.github/copilot-instructions.md` for repo-specific guidance (architecture, workflows, conventions, gotchas). Ensure any tests or scripts you run use a timeout (e.g., `timeout 60s <cmd>`).

## Roadmaps & Workstreams

- MVP goals and acceptance criteria: see `MVP_TODO.md`.
- Parallel team plan (epics and tasks): see `WORKSTREAMS.md`.

## License

Copyright © 2025 Hunt Master Academy. All rights reserved.

---

## Notes

- SQL files in `database/` are actively maintained - check commit history
- Production deployment uses Kubernetes - see [hma-deployment](../hma-deployment)
- ML models are stored in [hma-ai-models](../hma-ai-models)
- For mobile development, see field guide repos
```

## Key Additions Your README Was Missing:

1. **Comprehensive Table of Contents** - For easy navigation
2. **System Requirements** - Clear prerequisites
3. **Architecture Overview** - Visual schema organization  
4. **Environment Variables Documentation** - What each var does
5. **Database Management Commands** - Migration, seeding, backup procedures
6. **Compliance Section** - Critical for your 18+ requirement and regulations
7. **Performance & Scaling Targets** - Your specified DAU and storage needs
8. **Troubleshooting Guide** - Common issues and solutions
9. **Testing Procedures** - How to validate changes
10. **Contributing Guidelines** - Team collaboration standards
11. **Related Repositories** - Links to other services
12. **Security Features** - Highlighting compliance measures
13. **Monitoring Information** - Observability endpoints
14. **Support Resources** - Where to get help