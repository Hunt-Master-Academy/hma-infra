# HMA Infra – Parallel Workstreams Plan

This roadmap enables multiple teams to work concurrently toward the project objectives. Each workstream lists objectives, deliverables, acceptance criteria, dependencies, and a starter epic with sub-tasks you can open as GitHub issues (use the provided issue templates).

Conventions
- Labels: infra, database, ml, ci-cd, observability, security, docs, backups, good-first-issue
- Branch naming: ws/<workstream>/<short-topic> (e.g., ws/database/rls-baseline)
- Timeouts: All scripts/tests in CI must use timeout to avoid hangs
- Done = merged to main, docs updated, and smoke tests pass

## Workstream A – Local Dev Infra (Compose)
Objectives
- Reliable local stack: Postgres+PostGIS, Redis, MinIO, Adminer, Redis Commander, ML stub
- Clean docker compose config (v2), healthchecks, resource limits

Deliverables
- docker/docker-compose.yml validated warning-free
- prod/test variants aligned and documented

Acceptance
- `docker compose -f docker/docker-compose.yml config` has no warnings
- `scripts/setup-dev-environment.sh` succeeds end-to-end on a clean machine

Dependencies
- Minimal: shared `.env` schema across scripts

Epic: A1 Compose hardening
- A1.1 Remove deprecated version key and validate
- A1.2 Document dev/test/prod deltas in README
- A1.3 Ensure MinIO bucket creation uses correct network name

## Workstream B – Database & Migrations
Objectives
- Own the schema via migrations; idempotent apply/status; seeds for dev

Deliverables
- Versioned migrations for auth/users/sessions/legal_acceptance, partitioned audit_log
- Functions/triggers for updated_at and audit
- Seed data for reference + test users

Acceptance
- `./scripts/migrate.sh apply` and `status` clean on empty DB
- Under-18 insert fails due to CHECK; audit writes route to current-month partition

Dependencies
- None for dev; app services consume later

Epic: B1 Auth core migrations
- B1.1 Users + sessions + legal_acceptance with constraints
- B1.2 Partitioned audit_log + monthly partition helper
- B1.3 updated_at trigger + audit triggers wired
- B1.4 Seed test users; idempotent seeds

Epic: B2 RLS baseline (opt-in)
- B2.1 Enable RLS on auth.*; create policies for owner-only
- B2.2 Grant review for `hma_app` and `analytics_reader`

## Workstream C – Security & Compliance
Objectives
- Age gate, least-privilege roles, data minimization, audit coverage

Deliverables
- Age CHECK + rejection path logged
- Role grants + default privileges per schema

Acceptance
- Connecting as `hma_app` can perform allowed actions; `analytics_reader` read-only to analytics
- Attempted underage registration rejected and audited

Dependencies
- Depends on DB workstream B

Epic: C1 Roles and RLS
- C1.1 Default privileges for app/analytics roles
- C1.2 RLS policies on auth tables

## Workstream D – CI/CD & Quality Gates
Objectives
- Cost-aware CI that runs on demand (alpha-* tags/manual/label) with timeouts

Deliverables
- CI job that lints shell, validates compose, runs setup, smoke, migrations, seeds
- Optional: weekly restore test gated behind alpha

Acceptance
- CI only runs when gated; passes on green with timeouts enforced

Dependencies
- A/B scripts reliable locally

Epic: D1 Quality gates
- D1.1 Add shellcheck/sqlfluff (or psql parse) linters
- D1.2 Add backup/restore verification job (opt-in)

## Workstream E – Observability & Monitoring
Objectives
- Basic DB/Redis metrics and troubleshooting scripts; optional Prometheus stack

Deliverables
- db-stats, slow-queries, cache-stats scripts (present)
- Optional: Prometheus + Postgres exporter + starter dashboard

Acceptance
- Scripts run with timeouts; optional stack scrapes metrics locally

Dependencies
- A for compose services

Epic: E1 Prometheus (optional)
- E1.1 Add prom stack and scrape configs
- E1.2 Document dashboard import and links

## Workstream F – ML Server (Stub → Contract)
Objectives
- Health endpoint and minimal contract; integration smoke test

Deliverables
- /health and /models endpoints; script to call and assert 200 OK

Acceptance
- Smoke test includes ML HTTP checks with timeout

Dependencies
- A running compose stack; B for model registry table

Epic: F1 ML contract baseline
- F1.1 Add /models reading registry
- F1.2 Add smoke test step in CI (gated)

## Workstream G – Backups & DR
Objectives
- Manual backup/restore scripts now; schedule + retention later

Deliverables
- Daily backup job (opt-in) with pruning policy

Acceptance
- Restore test passes against a clean DB

Dependencies
- B migrations complete

Epic: G1 Scheduled backups
- G1.1 Add daily backup scheduler (cron/compose)
- G1.2 Add retention pruning
- G1.3 Add restore test script and doc

## Workstream H – Documentation & DX
Objectives
- Keep README accurate; add runbooks; onboarding smooth

Deliverables
- README links to MVP_TODO and this plan
- Runbooks for onboarding and common ops

Acceptance
- New dev can bring up stack in <10 min following docs

Epic: H1 Docs hardening
- H1.1 Add onboarding runbook
- H1.2 Add recovery drills doc

---

How to use this plan
1) Create epics from the items above using .github/ISSUE_TEMPLATE/workstream-epic.md
2) Break into tasks using .github/ISSUE_TEMPLATE/task.md
3) Use labels to slice by workstream, and milestones to target MVP vs. alpha
4) Keep PRs small, reference the epic ID, and include a smoke step locally before push
