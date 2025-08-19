Title: Local Development – AI Readme (Checklist Scaffold)

Purpose
- Rapid iteration with Docker Compose supporting pillar isolation and full-stack integration.

Stack
- Model serving (TF Serving / TorchServe), PostgreSQL+PostGIS, MinIO (S3), MLflow, Prometheus, Grafana.

Checklist
- [ ] compose files per pillar and one full-stack.
- [ ] model serving containers with health checks.
- [ ] PostGIS and seed scripts; example spatial queries.
- [ ] MinIO buckets and IAM-style policies; sample datasets.
- [ ] MLflow tracking server and artifact store.
- [ ] Monitoring stack with dashboards and alerts.
- [ ] resource-constrained profiles simulating mobile devices.
