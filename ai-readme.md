Title: Infrastructure – AI Readme (Overview)

Three-tier strategy: Local (Docker Compose) → Firebase Beta → AWS Production (SageMaker, Greengrass, CloudWatch).

Checklist to create todo_checklist.md
- [ ] Define pillar-specific local stacks and integration tests.
- [ ] Beta Firebase setup: device testing, A/B experiments, feedback loops.
- [ ] Production AWS setup: endpoints, edge deployments, monitoring.
- [ ] CI/CD pipelines with promotion and rollback.
- [ ] Cost, reliability, and security guardrails documented.
