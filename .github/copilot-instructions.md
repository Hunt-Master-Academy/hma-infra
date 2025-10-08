# Copilot instructions for hma-infra

Purpose: This repo provides the local infrastructure for Hunt Master Academy. It’s a Docker Compose stack with Postgres + PostGIS, Redis, MinIO, Adminer, Redis Commander, and a stub ML server, plus SQL schemas, migrations, seeds, and helper scripts.

## Big picture
- Orchestration: `docker/docker-compose.yml` (note: compose file lives in `docker/`). Always run with `docker compose -f docker/docker-compose.yml ...`.
- Services/ports: Postgres 5432, Redis 6379, MinIO 9000/9001, Adminer 8080, Redis Commander 8081, ML server 8010->8000.
- Data flows: App code talks to Postgres (primary store), Redis (cache/queues), and MinIO (objects). ML server consumes these via env: `REDIS_URL`, `POSTGRES_URL`, `MINIO_*`.
- Why structured this way: fast local bring-up that mirrors production resources; DB-first design with clear schemas and compliance.

## Critical workflows
- One-shot setup: `bash scripts/setup-dev-environment.sh` creates `.env`, brings up services, initializes DB, and creates MinIO buckets.
- Health check: `scripts/smoke-test.sh` validates DB/Redis/MinIO/ML availability.
- Migrations: place `V####__name.sql` in `database/migrations/`.
  - Tracking table: `infra.schema_migrations` (created by `V0001__create_schema_migrations.sql`).
  - Runner: `scripts/migrate.sh [apply|status]` applies files not present in `infra.schema_migrations`.
  - Rollback: not implemented; add a down path or adopt Flyway/Liquibase if needed.
- Seeding: `scripts/seed.sh [--test-users|<file.sql>]`. Test users assume adult birthdates and bcrypt/crypt-compatible hashing.
- Backups/restore: `scripts/backup-database.sh`, `scripts/restore-database.sh`. Daily scheduling to be added later.

## Test and run safety
- Always run tests and long-running checks with a timeout to avoid hangs.
  - Shell: prefix with `timeout 60s <cmd>` (tune seconds per context).
  - Load test: pass an explicit duration (e.g., `./scripts/load-test.sh --users 1000 --duration 60s`).
  - Benchmarks: limit runtime (e.g., wrap `./scripts/benchmark.sh` in `timeout`).
  - CI/automation: every test or script step must specify a timeout.
    - See `.github/workflows/ci.yml` for a reference pipeline using timeouts on setup, smoke, migrations, and seeds.

## Project structure and key files
- `docker/docker-compose.yml`: Main stack. Volumes mount `../database/init` to `/docker-entrypoint-initdb.d` and `../database/backups` to `/backups`.
- `database/init/01_init_database.sh`: Bootstraps extensions (uuid-ossp, pgcrypto, pg_trgm, btree_gin, btree_gist, postgis, postgis_topology, pg_stat_statements), creates schemas and roles (`hma_app`, `analytics_reader`).
- `database/init/schema.sql`: Minimal starter tables (auth.users, ml_infrastructure.model_registry, content.assets) for first-run.
- `database/migrations/`: Versioned SQL. `V0001__create_schema_migrations.sql` + `V0002__auth_core.sql` (users, sessions, legal_acceptance, audit_log parent + monthly partition, indexes).
- `database/seeds/`: Reference + dev data. `02_test_users.sql` inserts adult users.
- `scripts/`: Orchestration (setup, migrate, seed, backup/restore, reset, db/redis monitors, smoke tests).
- `ml-server/`: FastAPI stub (entry `src/main.py`) built by Compose; external port is 8010.
- `MVP_TODO.md`: Prioritized infra roadmap for MVP.

## Conventions and patterns
- Compose lives in a subfolder; prefer `docker compose -f docker/docker-compose.yml ...` (scripts already do this).
- SQL style: lowercase snake_case; schemas are predeclared (auth, users, content, progress, game_calls, hunt_strategy, stealth_scouting, tracking_recovery, gear_marksmanship, ml_infrastructure, analytics, events).
- Compliance: age-gating is enforced by a CHECK on `auth.users.birth_date` (see migrations). Audit logging uses partitioned tables; RLS planned but not yet enabled.
- Secrets: `.env` is generated and gitignored; don’t hardcode secrets in code or SQL.

## Examples
- Bring up + init: `bash scripts/setup-dev-environment.sh`
- Apply migrations: `./scripts/migrate.sh`
- Check status: `./scripts/migrate.sh status`
- Seed dev users: `./scripts/seed.sh --test-users`
- PSQL access: `docker compose -f docker/docker-compose.yml exec postgres psql -U hma_admin -d huntmaster`
- ML health: `curl http://localhost:8010/`
- Smoke with timeouts: `timeout 90s ./scripts/smoke-test.sh`

## Gotchas
- If ML port 8000 is taken on host, Compose maps service to host 8010; docs and smoke test target 8010.
- MinIO bucket creation uses `minio/mc` with `MC_HOST_local`; requires services to be up and on network `docker_hma_network`.
- Don’t rely on legacy `docker-compose` in scripts; this repo standardizes on `docker compose -f docker/docker-compose.yml`.

## Quality gates and practices
- DB changes must go through `database/migrations/` (no ad-hoc edits to `init/schema.sql`).
- Seeds must be idempotent (use `ON CONFLICT DO NOTHING` or equivalent guards).
- Validate compose after edits: `docker compose -f docker/docker-compose.yml config` (should be warning-free).
- Prefer minimal, pinned dependencies; do not commit secrets or `.env`.

## Documentation Standards - HMA Wiki

**🚨 CRITICAL: All comprehensive documentation must be created in the HMA Documentation Wiki.**

**Wiki Location**: `/home/xbyooki/projects/hma-docs/`

**Allowed in THIS project directory**:
- ✅ `README.md` - Project overview with links to wiki
- ✅ `MVP_TODO.md` - Infrastructure roadmap and task tracking
- ✅ Code comments and inline documentation
- ✅ Script documentation (in script headers)

**MUST be created in HMA Wiki** (NOT in this project):
- ❌ Architecture documentation → Use `/hma-docs/architecture/`
- ❌ Deployment guides → Use `/hma-docs/deployment/`
- ❌ Docker setup guides → Use `/hma-docs/getting-started/docker-setup.md`
- ❌ Database schema docs → Use `/hma-docs/architecture/database-schema.md`
- ❌ Migration guides → Use `/hma-docs/archive/migrations/`
- ❌ Infrastructure monitoring → Use `/hma-docs/architecture/`

**When creating new documentation**:
1. Check if topic exists in wiki: `/hma-docs/deployment/` or `/hma-docs/architecture/`
2. If yes: Update existing wiki doc, don't create duplicate
3. If no: Create in wiki with proper naming: `lowercase-with-hyphens.md`
4. Update wiki section README to link to new doc
5. Link from this project's README to wiki location

**Example**:
```bash
# ❌ WRONG - Don't create comprehensive docs here
/home/xbyooki/projects/hma-infra/DOCKER_ARCHITECTURE.md

# ✅ CORRECT - Create in wiki
/home/xbyooki/projects/hma-docs/architecture/docker-environment.md

# Then link from project README
See [Docker Environment](../hma-docs/architecture/docker-environment.md)
```

**Wiki Documentation**: See `/home/xbyooki/projects/hma-docs/README.md` for complete wiki structure and navigation.
