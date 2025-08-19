# HMA Infrastructure – MVP TODO

A focused checklist to deliver a reliable, local-first infrastructure MVP for Hunt Master Academy. Each item includes scope, status, and acceptance criteria. Use this to plan and track work across Docker, Database, Scripts, Monitoring, Security, and Docs.

Legend: [x] Done • [~] In Progress • [ ] TODO • (Optional) Nice-to-have for MVP+.

## 0) MVP Definition

- [ ] MVP Goal: Local dev stack with Postgres+PostGIS, Redis, MinIO, Adminer, Redis Commander, and an ML stub, plus minimal schemas, seeds, backups, and health scripts to support early app development.
- [ ] Success Criteria:
  - Bring-up: Single command boots all services healthy on fresh machine.
  - DB: Core schemas present; migrations/seed runnable; backup/restore works.
  - Security: Password-protected Redis; distinct DB app user; .env not committed.
  - Observability: Basic scripts for DB/Redis stats; logs directories; minimal alerts doc.

## 1) Docker/Compose Stack

- [x] Compose file under `docker/docker-compose.yml` with services: postgres, redis, minio, adminer, redis-commander, ml-server.
- [x] Volumes for persistent data (Postgres, Redis, MinIO).
- [x] Healthchecks for core services (postgres, redis, minio).
- [x] Resource limits (memory) for Postgres.
- [~] Remove deprecated `version:` key from compose to silence warning.
  - Acceptance: `docker compose config` shows no deprecation warnings.
- [ ] Production/test variants aligned (`docker/docker-compose.prod.yml`, `docker/docker-compose.test.yml`) and documented deltas.
  - Acceptance: README docs list differences; files validate via `docker compose -f ... config`.
- [ ] Network naming consistency across scripts (ensure setup script derivation matches compose network).
  - Acceptance: MinIO bucket creation attaches to the correct network without manual tweaks.

## 2) PostgreSQL (Core)

- [x] Base image with PostGIS and extensions bootstrap via `/docker-entrypoint-initdb.d`.
- [x] Extensions enabled: uuid-ossp, pgcrypto, pg_trgm, btree_gin, btree_gist, postgis, postgis_topology, pg_stat_statements.
- [ ] Extensions considered (Optional): pgvector, timescaledb.
  - Decision/Acceptance: Document decision in README; if enabled, add install/init scripts and verify `CREATE EXTENSION` succeeds.
- [x] Schemas scaffolded: auth, users, content, progress, game_calls, hunt_strategy, stealth_scouting, tracking_recovery, gear_marksmanship, ml_infrastructure, analytics, events.
- [ ] Roles & privileges
  - [x] `hma_admin` superuser from container env
  - [x] `hma_app` application user with grants
  - [x] `analytics_reader` read-only role
  - [ ] Default privileges per schema for app and analytics roles
  - Acceptance: Connecting as `hma_app` can SELECT/INSERT in allowed schemas; `analytics_reader` can only SELECT in `analytics`.
- [ ] Row-Level Security (RLS) on sensitive tables (auth.* as baseline)
  - Acceptance: RLS enabled; policies exist; unauthorized access denied in tests.
- [ ] Maintenance settings and helpers
  - [ ] `pg_stat_statements` settings verified; sample query to confirm tracking
  - [ ] Vacuum/Analyze guidance in docs

## 3) Database Schema & Migrations

- [x] Minimal starter schema in `database/init/schema.sql` (auth.users, ml_infrastructure.model_registry, content.assets).
- [ ] Versioned migrations in `database/migrations/` for full MVP tables:
  - [ ] auth: users, refresh_tokens, sessions, legal_acceptance, audit_log (partitioned monthly), breach_log (Optional)
  - [ ] content: assets, topics, content_items, content_topics (xref)
  - [ ] progress: lessons, user_progress, badges (Optional)
  - [ ] ml_infrastructure: model_registry, processing_jobs, model_metrics
  - [ ] events: event_log (partitioned monthly) (Optional for MVP)
  - [ ] indexes, FKs, CHECK constraints (age >= 18), unique constraints
  - Acceptance: `./scripts/migrate.sh` applies cleanly on empty DB; `status` shows applied list.
- [ ] Migration tracking table (e.g., `public.schema_migrations`) + idempotent script runner.
  - Acceptance: Re-running migrations is a no-op; status reflects up-to-date.
- [ ] Seed data in `database/seeds/` for reference data and test users.
  - Acceptance: `./scripts/seed.sh` runs successfully; can seed all or specific file; `--test-users` works.
- [ ] Triggers & functions for audit logging, updated_at, and soft deletes.
  - Acceptance: INSERT/UPDATE/DELETE actions are captured in audit_log; updated_at auto-updates.

## 4) Security & Compliance (DB-first)

- [ ] Age gate enforcement
  - [ ] CHECK constraint on `auth.users.birth_date` ensures >= 18 years
  - [ ] Registration denial logged to `auth.audit_log`
  - Acceptance: Attempt to insert under-18 user fails and logs.
- [ ] Audit logging
  - [ ] `auth.audit_log` table partitioned monthly
  - [ ] Trigger-based inserts capturing actor, action, table, before/after (jsonb), ip/device (Optional)
  - Acceptance: Partitions auto-created for current month; writes route correctly.
- [ ] Data minimization & retention
  - [ ] Soft-delete with 30-day retention policy documented (and enforced where applicable)
  - [ ] PII encryption where needed (pgcrypto or app-level)
- [ ] Least-privilege roles documented (who uses what in dev/prod).

## 5) Redis (Cache/Queues)

- [x] Password-protected with `--requirepass` pulled from `.env`.
- [x] Persistence enabled with appendonly.
- [ ] Baseline keyspace and TTL conventions documented (e.g., 5m for hot data).
- [ ] Optional: Separate DB indexes for queues vs cache documented.

## 6) MinIO (Object Storage)

- [x] Local S3-compatible storage with console.
- [x] Buckets created: `huntmaster-media`, `huntmaster-models`, `huntmaster-backups` via setup script.
- [ ] Access policies (Optional): read-only/public for selected prefixes documented.
- [ ] Sample upload/download script (Optional) for dev verification.

## 7) ML Server (Stub)

- [x] FastAPI stub builds and runs in compose; exposes basic health/info.
- [ ] Minimal endpoints contract documented (e.g., `/health`, `/predict` noop, `/models` list from registry).
- [ ] Integration test script calls ML endpoints and verifies 200 OK.

## 8) Scripts & Tooling

- [x] `scripts/setup-dev-environment.sh` bootstraps `.env`, directories, services, DB init, and MinIO buckets.
- [x] Migration script (`scripts/migrate.sh`) with apply/status; rollback placeholder.
- [x] Seed script (`scripts/seed.sh`) supporting all/single/`--test-users`.
- [x] Backup/restore/reset scripts present.
- [x] Monitoring helpers: `db-stats.sh`, `slow-queries.sh`, `cache-stats.sh`.
- [ ] Implement rollback in `migrate.sh` (or adopt Flyway/Liquibase).
  - Acceptance: `rollback` reverses last migration or errors with clear guidance.
- [ ] Add `Makefile` convenience targets (Optional): make up/down/migrate/seed/backup.

## 9) Monitoring & Observability

- [ ] Compose services for Prometheus (and optionally Grafana) (Optional for MVP+).
  - Acceptance: Prometheus scrapes Postgres exporter and app endpoints; basic dashboard loads.
- [ ] Postgres exporter container and default scrape config (Optional).
- [ ] Logging:
  - [x] Central `/logs` directory exists
  - [ ] Log rotation guidance or sample config documented
- [ ] Alerts: Write initial runbook and example alert rules in `monitoring/` (Optional).

## 10) Backups & Disaster Recovery

- [x] Manual backup and restore scripts.
- [ ] Scheduled backups (cron/systemd or containerized job) with retention policy.
  - Acceptance: Daily backup artifacts land in `database/backups/`; oldest pruned per retention.
- [ ] Restore test automation (`scripts/backup/test-restore.sh`) included in CI weekly (Optional).
- [ ] Document offsite strategy for production (Optional; pointer to hma-deployment).

## 11) CI/CD & Quality Gates

- [ ] CI pipeline (Optional for MVP) that:
  - [ ] Lints SQL (psql parse or sqlfluff) and shell (shellcheck)
  - [ ] Spins up compose for smoke tests (DB connect, migrations, seeds)
  - [ ] Runs backup/restore test on ephemeral DB
  - Acceptance: PR status checks must pass before merge.

## 12) Documentation

- [x] Comprehensive README covering architecture, ops, compliance, and troubleshooting.
- [x] Docs stubs: `docs/database-design.md`, `docs/compliance-strategy.md`, `docs/scaling-strategy.md`, `docs/backup-recovery.md`.
- [ ] Keep README in sync with compose filenames and commands (compose v2 syntax).
 - [x] Add `MVP_TODO.md` link to README (Optional nicety).
- [ ] Add runbooks: onboarding, common ops, recovery drills (Optional).

## 13) Environments & Config

- [x] `.env` generation with secure defaults.
- [x] `.gitignore` excludes secrets, backups, logs, models.
- [ ] Parameterize sensible defaults via env for ports, memory, and paths where helpful.
- [ ] Document differences between dev/test/prod and how to override.

## 14) Performance Targets (MVP readiness)

- [ ] Indexes on FKs and common lookups created in migrations.
- [ ] GIN indexes for JSONB/text search where applicable.
- [ ] Partitioning for `auth.audit_log` (and `events.event_log` if included).
- [ ] Quick benchmarks doc for typical queries; link to `./scripts/slow-queries.sh`.

---

## Quick Wins to Tackle Next

1) Remove compose `version:` key and validate config is clean.  
2) Add migration tracking table and cut first real migrations for auth (users, sessions, legal_acceptance, audit_log + partitions).  
3) Implement `migrate.sh rollback` for last migration or document Flyway adoption.  
4) Add minimal `/health` endpoint test for ML server and wire into a smoke test script.  
5) Schedule daily backups with retention (7-14 days) and document restore procedure.

## Notes

- TimescaleDB/pgvector are optional for MVP; add when needed by features. If adopting, prefer an image that bundles the extension or a build step to install.
- Production Kubernetes specifics live in `hma-deployment`; this repo focuses on local/dev parity and DB schema ownership.

---

## Alpha Readiness Epics & Workstreams

This section captures the parallel work needed to reach alpha-testing readiness. Keep epic/task status updated here; no external project board is required. Suggested branch prefix: `ws/<workstream>/<short-topic>`.

Legend: Workstreams — A: Compose/Local Infra, B: Database/Migrations, C: Security/Compliance, D: CI/CD, E: Observability, F: ML Server, G: Backups/DR, H: Docs/DX.

### EPIC A1 – Compose Hardening (Workstream A)
Goals: Clean Compose v2 config, reliable bring-up, documented variants.
- [ ] A1.1 Remove deprecated `version:` key; validate config clean
- [ ] A1.2 Document dev/test/prod deltas in README; include ports/resources
- [ ] A1.3 Verify MinIO bucket creation uses the correct network name
Acceptance: `docker compose -f docker/docker-compose.yml config` has no warnings; setup script succeeds end-to-end on a clean machine.

### EPIC B1 – Auth Core Migrations (Workstream B)
Goals: Baseline auth schema with partitions and triggers.
- [ ] B1.1 Users, sessions, legal_acceptance tables with constraints and indexes
- [ ] B1.2 Partitioned `auth.audit_log` with current-month partition helper
- [ ] B1.3 `updated_at` trigger + audit triggers wired on auth tables
- [ ] B1.4 Seed test users; idempotent seeds and fixture refresh
Acceptance: `./scripts/migrate.sh apply` idempotent; under-18 insert fails; audit rows route to current month partition.

### EPIC B2 – RLS & Roles (Workstream B/C)
Goals: Least-privilege access and baseline RLS.
- [ ] B2.1 Default privileges per schema for `hma_app` and `analytics_reader`
- [ ] B2.2 Enable RLS on sensitive `auth.*` tables (owner-only baseline)
- [ ] B2.3 Role grant verification script or doc (connectivity matrix)
Acceptance: `hma_app` can SELECT/INSERT where allowed; `analytics_reader` SELECT-only in analytics; unauthorized access denied.

### EPIC C1 – Compliance Guardrails (Workstream C)
Goals: Enforce age gate and log denied registrations.
- [ ] C1.1 CHECK constraint for 18+ on `auth.users.birth_date`
- [ ] C1.2 Rejection path writes to `auth.audit_log` with reason and context
Acceptance: Inserting underage user fails with clear error and audit trail.

### EPIC D1 – CI Quality Gates (Workstream D)
Goals: Run-on-demand CI with timeouts and linters.
- [ ] D1.1 Add shellcheck for scripts (gated)
- [ ] D1.2 Add SQL lint or parse check (sqlfluff or `psql -c "EXPLAIN ..."` dry parses)
- [ ] D1.3 Keep current gates: alpha tags/manual/PR label + concurrency + path filters
Acceptance: CI passes when gated; all steps have explicit timeouts.

### EPIC E1 – Observability Bootstrap (Workstream E)
Goals: Troubleshooting visibility; optional Prometheus.
- [ ] E1.1 Ensure db-stats/slow-queries/cache-stats scripts document outputs
- [ ] E1.2 Optional: Add Prometheus + Postgres exporter compose and README notes
Acceptance: Scripts run with timeouts; optional stack scrapes metrics locally.

### EPIC F1 – ML Contract Baseline (Workstream F)
Goals: Minimal API and smoke coverage.
- [ ] F1.1 `/health` returns service/version; `/models` lists registry contents
- [ ] F1.2 Add smoke test script step for ML endpoints (timeout-protected)
Acceptance: Smoke step asserts 200 responses and basic payload contract.

### EPIC G1 – Scheduled Backups & Restore Test (Workstream G)
Goals: Daily backups with retention; restore confidence.
- [ ] G1.1 Add daily backup job (cron/compose) writing to `database/backups/`
- [ ] G1.2 Retention pruning (e.g., keep 7-14 days)
- [ ] G1.3 Automated restore test script for a fresh DB snapshot
Acceptance: Restore test passes; backup size/rotation documented.

### EPIC H1 – Docs & Onboarding (Workstream H)
Goals: Clear onboarding and runbooks.
- [ ] H1.1 Onboarding runbook: setup, common ops, smoke
- [ ] H1.2 Recovery drills: backup/restore walkthrough, failure scenarios
Acceptance: New dev can bring up stack in <10 minutes using docs.

Coordination Notes
- Prefer small PRs per sub-task; reference the EPIC code (e.g., A1.1)
- Always run local smoke with timeouts before pushing
- Keep this section as the single source of truth for epic/task status
