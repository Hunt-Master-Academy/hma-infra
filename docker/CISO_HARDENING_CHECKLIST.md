# CISO Assistant Production Hardening & Rollout Checklist

## 📋 Pre-Rollout Checklist (Staging Verification)

### Configuration Validation
- [x] Backend environment variables verified
- [x] Worker environment variables verified  
- [x] Secrets rotated from defaults (DJANGO_SECRET_KEY, DB passwords)
- [x] `DJANGO_DEBUG=False` confirmed
- [x] `ALLOWED_HOSTS` configured for production domains
- [ ] TLS certificates for production domain (currently self-signed)
- [ ] SMTP configured for email notifications
- [ ] Backup procedures tested and documented

### Database & Storage
- [x] PostgreSQL database created (`ciso_assistant`)
- [x] All migrations applied successfully
- [x] MinIO bucket created (`hma-compliance-evidence`)
- [ ] Database backup schedule configured
- [ ] MinIO lifecycle policies configured
- [ ] Connection pooling tuned for expected load

### Security Hardening
- [x] Strong SECRET_KEY from environment
- [x] Database credentials not in compose file  
- [x] MinIO credentials externalized
- [ ] Redis password authentication enabled
- [ ] Network isolation (separate Docker networks)
- [ ] Rate limiting configured (Caddy/API level)
- [ ] CORS policies reviewed and restricted
- [ ] Content Security Policy headers added

### Observability
- [ ] Structured logging configured (JSON format)
- [ ] Log aggregation setup (ELK/Loki/CloudWatch)
- [ ] Prometheus metrics exposed
- [ ] Grafana dashboards created
- [ ] Alerting rules configured
  - [ ] High error rate alert
  - [ ] Failed task queue retries
  - [ ] Disk usage >80%
  - [ ] Container restart loops
  - [ ] Database connection pool exhaustion

### Testing
- [ ] Authentication flows tested (login/logout/password reset)
- [ ] File upload/download tested (evidence attachments)
- [ ] Compliance assessment creation workflow
- [ ] Framework import tested (ISO 27001, SOC 2, GDPR)
- [ ] Scheduled tasks executing (auditlog_prune verified)
- [ ] Load test baseline (concurrent users, API throughput)
- [ ] Backup and restore verified in staging

---

## 🚀 Release Checklist (Production Cutover)

### Pre-Deployment
- [ ] Maintenance window scheduled and communicated
- [ ] Rollback plan documented and reviewed
- [ ] Database backup completed and verified
- [ ] MinIO snapshot/backup completed
- [ ] Team on standby for deployment

### Deployment Steps
1. [ ] Pull latest production images
   ```bash
   docker pull ghcr.io/intuitem/ciso-assistant-community/backend:latest
   docker pull ghcr.io/intuitem/ciso-assistant-community/frontend:latest
   ```

2. [ ] Update production secrets in `.env.compliance`
   ```bash
   CISO_DJANGO_SECRET=<new-50-char-secret>
   CISO_DB_PASSWORD=<new-secure-password>
   MINIO_PASSWORD=<new-secure-password>
   ```

3. [ ] Deploy with environment file
   ```bash
   cd /home/xbyooki/projects/hma-infra/docker
   docker compose -f docker-compose.compliance.yml --env-file .env.compliance up -d
   ```

4. [ ] Run database migrations
   ```bash
   docker exec hma_ciso_backend poetry run python manage.py migrate
   ```

5. [ ] Verify health endpoints
   ```bash
   curl -k https://localhost:8443/api/health/
   ```

### Post-Deployment Verification
- [ ] API health check passing
- [ ] Web interface accessible
- [ ] Admin login successful
- [ ] Worker processing tasks
- [ ] Database queries responding <100ms
- [ ] File upload/download working
- [ ] Email notifications sending (if configured)
- [ ] No errors in logs (30-minute observation)

---

## 📊 Post-Rollout Operations

### Monitoring (First 24 Hours)
- [ ] Monitor CPU usage (should be <50% average)
- [ ] Monitor memory usage (should be <70% average)
- [ ] Monitor disk I/O
- [ ] Monitor API response times (P95 < 500ms)
- [ ] Monitor error rates (should be <1%)
- [ ] Monitor Huey task queue length
- [ ] Check PostgreSQL slow query log
- [ ] Review Caddy access logs for anomalies

### Incident Response
- [ ] On-call rotation established
- [ ] Runbooks documented for common issues
- [ ] Escalation paths defined
- [ ] Communication channels setup (Slack/Teams)

### Scheduled Maintenance
- [ ] **Daily**: Review error logs and metrics
- [ ] **Weekly**: Database vacuum and analyze
- [ ] **Weekly**: Review and prune old audit logs
- [ ] **Monthly**: Security updates and dependency patches
- [ ] **Monthly**: Review and rotate TLS certificates
- [ ] **Quarterly**: Disaster recovery drill
- [ ] **Quarterly**: Capacity planning review

---

## 🔐 Security Operations

### Access Management
- [ ] Admin accounts reviewed (remove test accounts)
- [ ] Role-based access control (RBAC) configured
- [ ] Multi-factor authentication (MFA) enabled
- [ ] Password policies enforced (complexity, rotation)
- [ ] Failed login attempt monitoring

### Vulnerability Management
- [ ] Dependency scanning automated (Dependabot/Snyk)
- [ ] Container image scanning (Trivy/Clair)
- [ ] Penetration testing scheduled
- [ ] Security patches applied within SLA
- [ ] CVE monitoring for CISO Assistant upstream

### Compliance Auditing
- [ ] Audit log retention configured (90 days default)
- [ ] Access logs archived for compliance
- [ ] Change management process documented
- [ ] Compliance attestation reports generated
- [ ] Annual security assessment scheduled

---

## 📈 Performance Optimization

### Application Tuning
- [ ] Gunicorn worker count optimized (`2*CPU + 1`)
- [ ] Database connection pool sized (`max_connections`)
- [ ] Query optimization (identify N+1 queries)
- [ ] Static asset CDN configured
- [ ] Browser caching headers optimized

### Infrastructure Scaling
- [ ] Horizontal scaling tested (multiple backend replicas)
- [ ] Load balancer configured (HAProxy/Traefik)
- [ ] Database read replicas for reporting
- [ ] Redis cluster for high-availability Huey
- [ ] Object storage CDN (CloudFront/Cloudflare)

### Cost Optimization
- [ ] Resource limits tuned (CPU/memory)
- [ ] Unused volumes cleaned up
- [ ] Log retention policies optimized
- [ ] MinIO lifecycle policies for cold storage
- [ ] Reserved capacity purchased (if cloud)

---

## 🔄 Continuous Improvement

### Weekly Review
- [ ] Review error trends and patterns
- [ ] Analyze user feedback and support tickets
- [ ] Review performance metrics and bottlenecks
- [ ] Update documentation based on incidents

### Monthly Review
- [ ] Capacity planning (storage, CPU, memory growth)
- [ ] Security posture review
- [ ] Disaster recovery plan testing
- [ ] Team training on new features

### Quarterly Review
- [ ] Architecture review (scalability, reliability)
- [ ] Cost analysis and optimization
- [ ] Technology stack updates (Django, PostgreSQL versions)
- [ ] Roadmap planning (new compliance frameworks, integrations)

---

## 🚨 Rollback Procedures

### Immediate Rollback (Critical Issues)
```bash
# 1. Stop new deployment
cd /home/xbyooki/projects/hma-infra/docker
docker compose -f docker-compose.compliance.yml down

# 2. Restore database from backup
docker exec -i hma_postgres psql -U hma_admin -d ciso_assistant < backup_pre_deployment.sql

# 3. Restore previous image versions
docker compose -f docker-compose.compliance.yml pull <previous-version-tag>
docker compose -f docker-compose.compliance.yml up -d

# 4. Verify health
curl -k https://localhost:8443/api/health/

# 5. Notify team and document incident
```

### Partial Rollback (Non-Critical Issues)
```bash
# Roll back specific service
docker compose -f docker-compose.compliance.yml stop hma-ciso-backend
docker tag ghcr.io/intuitem/ciso-assistant-community/backend:previous-tag ghcr.io/intuitem/ciso-assistant-community/backend:latest
docker compose -f docker-compose.compliance.yml up -d hma-ciso-backend
```

---

## 📞 Emergency Contacts

### Internal Team
- **DevOps Lead**: [Name] - [Phone] - [Email]
- **Security Lead**: [Name] - [Phone] - [Email]
- **Database Admin**: [Name] - [Phone] - [Email]

### External Support
- **CISO Assistant Community**: https://github.com/intuitem/ciso-assistant-community/discussions
- **Critical Bug Reports**: https://github.com/intuitem/ciso-assistant-community/issues

---

## ✅ Final Sign-Off

### Deployment Approval
- [ ] **Technical Lead**: Name __________ Date __________ Signature __________
- [ ] **Security Officer**: Name __________ Date __________ Signature __________
- [ ] **Compliance Manager**: Name __________ Date __________ Signature __________

### Go-Live Decision
- [ ] All pre-rollout checks completed
- [ ] Rollback plan tested and verified
- [ ] Team briefed and prepared
- [ ] Stakeholders informed

**Production Readiness Status**: ⏳ PENDING FINAL CHECKLIST COMPLETION

---

*Document Version: 1.0*  
*Last Updated: October 23, 2025*  
*Next Review: November 23, 2025*
