# HMA Infra – TODO Checklist

Context
- Deliverables: Local dev (compose), CI/CD, Kubernetes, Terraform, monitoring.
- Success: Fast local iteration, reliable deployments, observability, cost control.

## Phase 1 – Foundation
- [ ] INFRA-01 [C] Local dev stacks
  - Deliverable: local-dev compose per pillar + full-stack
  - Success: Dev spin-up < 5 min; docs included
  - Effort: 2pd
- [ ] INFRA-02 [H] CI runners and caching
  - Deliverable: CI config with artifact caching
  - Success: Build time reduction ≥30%
  - Effort: 1pd

## Phase 2 – Implementation
- [ ] INFRA-03 [H] ML-specific CI gates
  - Deliverable: model inference tests; schema checks
  - Success: Blocks contract/accuracy regressions
  - Effort: 2pd
- [ ] INFRA-04 [M] Kubernetes Helm charts (optional early)
  - Deliverable: charts/ with values schemas
  - Success: Staging deploy in <15min
  - Effort: 3pd
- [ ] INFRA-05 [H] Terraform modules
  - Deliverable: terraform/ aws, firebase, monitoring, security
  - Success: Reproducible envs (dev/beta/prod)
  - Effort: 3pd

## Phase 3 – Validation
- [ ] INFRA-06 [H] Monitoring & SLOs
  - Deliverable: dashboards, alerts, drift detectors
  - Success: Actionable alerts with runbooks
  - Effort: 2pd
- [ ] INFRA-07 [M] Rollback & canary
  - Deliverable: playbooks + automation hooks
  - Success: Canary→full rollout with guardrails
  - Effort: 2pd

Risks: Team bandwidth → prioritize compose + CI gates first; Cloud cost → cost budgets & alerts.
