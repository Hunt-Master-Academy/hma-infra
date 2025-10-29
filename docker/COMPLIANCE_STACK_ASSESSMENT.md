# HMA Compliance & Security Stack Deployment Assessment

**Assessment Date**: October 23, 2025  
**Objective**: Deploy CISO Assistant (GRC) and Wazuh (SIEM) to achieve ISO 27001 and SOC 2 compliance from day 1

## Current Infrastructure Assessment

### Existing Docker Environment

**Running Services** (15 containers):
- **Core Infrastructure**: PostgreSQL 16 + PostGIS, Redis 7.2, MinIO S3-compatible storage
- **Application Services**: hma-academy-web (React PWA), hma-academy-api (Gateway), hma-academy-brain (Backend)
- **Observability Stack**: Prometheus, Grafana, Alertmanager, Jaeger (distributed tracing), Blackbox Exporter
- **Management Tools**: Adminer (DB), Redis Commander
- **Metrics Exporters**: PostgreSQL Exporter, Redis Exporter

### Resource Utilization (Current)

**System Resources Available**:
- **Total RAM**: 31 GiB (31,744 MiB)
- **Used RAM**: 7.3 GiB (current workload)
- **Available RAM**: 24 GiB for new services
- **CPU Cores**: 8 cores
- **Disk Space**: 725 GB available (1007 GB total, 232 GB used)
- **Swap**: 12 GiB (unused)

**Current Container Memory Usage**:
```
hma_jaeger:             438.7 MiB (largest consumer)
hma-academy-web:        154.2 MiB
hma_minio:              130.1 MiB
hma_grafana:            92.4 MiB
hma-academy-brain:      85.7 MiB
hma_postgres:           75.1 MiB (2GB limit)
hma_prometheus:         70.3 MiB
hma-academy-api:        56.7 MiB
hma_redis_commander:    57.4 MiB
hma_adminer:            16.4 MiB
hma_alertmanager:       15.1 MiB
Others:                 ~70 MiB combined
TOTAL CURRENT:          ~1.3 GB
```

**CPU Usage**: All containers operating at <1% CPU (very light load)

### Infrastructure Strengths for Compliance Stack

✅ **PostgreSQL 16 with PostGIS**: Production-ready database with checksums enabled, can host multiple databases  
✅ **Existing Monitoring Stack**: Prometheus + Grafana ready for compliance metrics integration  
✅ **Network Isolation**: Dedicated `hma-network` for service communication  
✅ **Health Checks**: All critical services have health checks configured  
✅ **Storage Infrastructure**: MinIO S3-compatible storage for evidence collection  
✅ **Observability**: Jaeger tracing + Prometheus metrics provide audit trail foundation  
✅ **Resource Headroom**: 24 GB available RAM far exceeds compliance stack requirements

### Gaps Requiring Remediation

❌ **No SIEM Platform**: No centralized security event monitoring or log aggregation  
❌ **No GRC Platform**: No governance, risk, or compliance management system  
❌ **No Compliance Framework Implementation**: No ISO 27001, SOC 2, GDPR, or CCPA controls  
❌ **No Centralized Audit Logging**: Application logs not aggregated for security analysis  
❌ **No Threat Detection**: No anomaly detection or security alerting  
❌ **No Evidence Repository**: No systematic evidence collection for audits  
❌ **No Policy Management**: No centralized policy and procedure documentation  
❌ **No Risk Register**: No formal risk assessment and tracking system

## Recommended Deployment Stack

### Stack Choice: CISO Assistant + Wazuh

Based on the comprehensive analysis in `Compliance_Security_Development.md`, this combination provides:

**CISO Assistant (GRC/ISMS/Compliance)**:
- Full ISO 27001:2013 & 2022 implementation
- SOC 2 Type I and Type II controls
- GDPR compliance framework
- CCPA compliance (only open-source tool with explicit support)
- 100+ additional frameworks (NIST CSF, PCI DSS, HIPAA, etc.)
- Built-in risk assessment and treatment workflows
- Policy management with version control
- Centralized evidence repository
- Audit planning and execution
- Modern architecture (Django + SvelteKit)
- Active development (3,100+ GitHub stars)

**Wazuh (SIEM/XDR)**:
- Comprehensive security monitoring
- AWS CloudWatch integration (CloudTrail, GuardDuty, VPC Flow Logs)
- Container monitoring (Docker listener module)
- File integrity monitoring
- Built-in compliance frameworks (PCI-DSS, HIPAA, GDPR)
- Threat detection and anomaly detection
- 9,100+ GitHub stars, very active development
- No agent limits or licensing restrictions

### Resource Requirements Estimate

**CISO Assistant**:
- Backend (Django): 512 MB - 1 GB RAM, 0.5 CPU
- Frontend (SvelteKit): 256 MB - 512 MB RAM, 0.25 CPU
- Database (PostgreSQL - shared): Marginal increase in existing DB
- **Subtotal**: ~1 GB RAM, 0.75 CPU

**Wazuh Stack**:
- Wazuh Manager: 1 GB - 2 GB RAM, 1 CPU
- Wazuh Indexer (OpenSearch): 2 GB - 4 GB RAM (with constrained heap), 1-2 CPU
- Wazuh Dashboard: 512 MB - 1 GB RAM, 0.5 CPU
- **Subtotal**: 4 GB - 7 GB RAM, 2.5-3.5 CPU

**Caddy Reverse Proxy**:
- 128 MB - 256 MB RAM, 0.25 CPU

**Total Additional Resources Required**:
- **RAM**: 5-8 GB (well within 24 GB available)
- **CPU**: 3.5-4.5 cores (well within 8 cores available)
- **Storage**: ~10-20 GB initially (logs, evidence, indices)

**Safety Margin**: Current usage ~1.3 GB + Compliance stack ~8 GB = ~9.3 GB total (70% headroom remaining)

### Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        HMA Network (Docker)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐         ┌──────────────────┐              │
│  │   Caddy Proxy    │◄────────┤  Internet/LAN    │              │
│  │   (TLS/HTTPS)    │         │   (Reverse)      │              │
│  └────────┬─────────┘         └──────────────────┘              │
│           │                                                       │
│  ┌────────▼──────────────────────────────────────────┐          │
│  │                                                     │          │
│  │  ┌──────────────┐       ┌──────────────────┐      │          │
│  │  │ CISO Asst.   │       │  Wazuh Dashboard │      │          │
│  │  │  Frontend    │       │   (Kibana-like)  │      │          │
│  │  │ (Port 8443)  │       │   (Port 5601)    │      │          │
│  │  └──────┬───────┘       └────────┬─────────┘      │          │
│  │         │                         │                 │          │
│  │  ┌──────▼───────┐       ┌────────▼─────────┐      │          │
│  │  │ CISO Asst.   │       │ Wazuh Manager    │      │          │
│  │  │  Backend     │       │  (Core Service)  │      │          │
│  │  │  (Django)    │       │                  │      │          │
│  │  └──────┬───────┘       └────────┬─────────┘      │          │
│  │         │                         │                 │          │
│  └─────────┼─────────────────────────┼────────────────┘          │
│            │                         │                            │
│  ┌─────────▼────────┐      ┌────────▼─────────┐                 │
│  │   PostgreSQL     │      │ Wazuh Indexer    │                 │
│  │   (Shared DB)    │      │  (OpenSearch)    │                 │
│  │  - hma_academy   │      │  (Logs/Events)   │                 │
│  │  - ciso_assistant│      └──────────────────┘                 │
│  │  - wazuh_db      │                                            │
│  └──────────────────┘                                            │
│                                                                   │
│  ┌────────────────────────────────────────────────────┐         │
│  │         Existing HMA Services                       │         │
│  │  - hma-academy-web (Frontend)                      │         │
│  │  - hma-academy-brain (Backend) ◄───┐               │         │
│  │  - hma-academy-api (Gateway)       │               │         │
│  │  - Redis, MinIO                    │               │         │
│  │  - Prometheus, Grafana, Jaeger ────┤ Integration   │         │
│  │                                     │               │         │
│  └─────────────────────────────────────┴───────────────┘         │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### Integration Points

**Shared Infrastructure**:
1. **PostgreSQL**: Create separate databases `ciso_assistant` and `wazuh_db` in existing PostgreSQL instance
2. **Prometheus**: Scrape Wazuh metrics for security monitoring dashboards
3. **Grafana**: Create compliance dashboards showing security posture and audit metrics
4. **MinIO**: Use for evidence storage (CISO Assistant) and log archives (Wazuh)
5. **Redis**: Optional shared cache for CISO Assistant background tasks

**Data Flow**:
1. Application logs → Wazuh Manager → Wazuh Indexer → Security analysis
2. Security findings → CISO Assistant evidence repository → Compliance reporting
3. Compliance alerts → Prometheus → Alertmanager → Notification channels
4. Audit events → Wazuh → Grafana dashboards → Executive visibility

## Deployment Strategy

### Phase 1: Infrastructure Preparation (Week 1)

**Day 1-2: Database Setup**
- Create `ciso_assistant` database in PostgreSQL
- Create `wazuh_db` database for Wazuh metadata
- Configure database users with appropriate permissions
- Test connectivity and permissions

**Day 3-4: Network Configuration**
- Ensure `hma-network` supports new services
- Configure firewall rules for compliance stack ports
- Set up DNS entries or host file mappings
- Plan reverse proxy routes

**Day 5-7: Security Hardening**
- Generate strong passwords for all services (store in `.env.compliance`)
- Set up TLS certificates (Let's Encrypt or self-signed for testing)
- Configure secrets management (prepare for AWS Secrets Manager migration)
- Document security controls in CISO Assistant once deployed

### Phase 2: CISO Assistant Deployment (Week 2)

**Day 1-2: Initial Deployment**
- Create `docker-compose.compliance.yml` with CISO Assistant services
- Deploy backend and frontend containers
- Configure PostgreSQL connection
- Verify health checks and startup

**Day 3-4: Framework Configuration**
- Import ISO 27001:2022 framework
- Import SOC 2 controls
- Import GDPR compliance checklist
- Import CCPA framework
- Set up initial risk assessment templates

**Day 5-7: Integration & Testing**
- Connect MinIO for evidence storage
- Configure email notifications (SMTP)
- Set up user accounts and RBAC
- Create initial policies and procedures
- Test complete workflow (policy → control → evidence → audit)

### Phase 3: Wazuh SIEM Deployment (Week 3)

**Day 1-3: Core Deployment**
- Deploy Wazuh Manager, Indexer, Dashboard
- Set kernel parameter: `vm.max_map_count=262144`
- Configure Wazuh Manager with agents for Docker hosts
- Set up authentication and access controls
- Verify all services healthy

**Day 4-5: Log Integration**
- Configure Docker log drivers to forward to Wazuh
- Set up file integrity monitoring for critical paths
- Configure security event rules (MITRE ATT&CK)
- Test alert generation and response

**Day 6-7: AWS Integration**
- Configure AWS CloudWatch log ingestion
- Set up CloudTrail monitoring
- Configure GuardDuty integration
- Test AWS security event detection

### Phase 4: Integration & Automation (Week 4)

**Day 1-2: Monitoring Integration**
- Add Wazuh metrics to Prometheus scrape configs
- Create Grafana dashboards for security posture
- Configure alerting rules for compliance violations
- Set up notification channels (Slack, email, PagerDuty)

**Day 3-4: Evidence Automation**
- Configure automated evidence collection from Wazuh to CISO Assistant
- Set up scheduled compliance scans
- Create automated reporting for control effectiveness
- Test end-to-end compliance workflow

**Day 5-7: Documentation & Training**
- Create operational runbooks for compliance stack
- Document incident response procedures
- Create user guides for CISO Assistant
- Train team on security monitoring and compliance workflows
- Conduct tabletop exercise for security incident

### Phase 5: Production Validation (Week 5-6)

**Week 5: Testing**
- Conduct penetration testing simulation
- Validate all compliance controls operational
- Test disaster recovery procedures
- Verify audit trail completeness
- Performance testing under load

**Week 6: Hardening & Go-Live**
- Address any findings from testing
- Fine-tune resource allocations
- Conduct final security review
- Go-live with compliance stack
- Begin continuous monitoring

## Success Criteria

### Technical Success Metrics

✅ **SIEM Operational**:
- [ ] Wazuh collecting logs from all Docker containers
- [ ] AWS CloudWatch integration active
- [ ] Security alerts generating within 5 minutes of events
- [ ] Dashboard accessible with <2 second load time
- [ ] 99.9% uptime for Manager and Indexer

✅ **GRC Platform Functional**:
- [ ] All 4 frameworks loaded (ISO 27001, SOC 2, GDPR, CCPA)
- [ ] Evidence repository storing artifacts from infrastructure
- [ ] Automated control testing scheduled
- [ ] Audit reports generating successfully
- [ ] Policy management workflow operational

✅ **Integration Complete**:
- [ ] Prometheus scraping Wazuh metrics
- [ ] Grafana dashboards showing compliance status
- [ ] Alerts forwarding to Alertmanager
- [ ] Evidence flowing from Wazuh to CISO Assistant
- [ ] MinIO storing compliance artifacts

✅ **Performance Targets Met**:
- [ ] Total stack memory usage <12 GB
- [ ] CPU utilization <60% during normal operations
- [ ] Log ingestion lag <1 minute
- [ ] Query response time <3 seconds (95th percentile)
- [ ] Evidence retrieval <5 seconds

### Compliance Success Metrics

✅ **ISO 27001 Ready**:
- [ ] All 93 controls mapped to technical implementations
- [ ] Statement of Applicability (SoA) generated
- [ ] Risk assessment completed for all assets
- [ ] Policies documented and version controlled
- [ ] Evidence collected for 100% of required controls

✅ **SOC 2 Type I Ready**:
- [ ] All Trust Service Criteria controls implemented
- [ ] Security, Availability, Confidentiality controls validated
- [ ] System description documented
- [ ] Access controls tested and verified
- [ ] Evidence repository ready for auditor access

✅ **GDPR Compliant**:
- [ ] Data Processing Record maintained
- [ ] Privacy controls implemented
- [ ] Data subject rights procedures documented
- [ ] Breach notification process tested
- [ ] Privacy by design principles applied

✅ **CCPA Baseline Achieved**:
- [ ] Consumer rights management procedures
- [ ] Data inventory maintained
- [ ] Opt-out mechanisms documented
- [ ] Vendor risk assessments initiated
- [ ] Privacy policy updated

## Risk Assessment

### Deployment Risks

**HIGH RISK - Resource Contention**:
- **Risk**: Wazuh Indexer consuming excessive memory impacting other services
- **Mitigation**: Set JVM heap limits (2-3 GB max), monitor with Prometheus alerts
- **Contingency**: Deploy Wazuh on separate host if resource pressure detected

**MEDIUM RISK - Network Complexity**:
- **Risk**: Service discovery issues or routing conflicts in Docker network
- **Mitigation**: Thorough testing in staging, clear naming conventions, network isolation
- **Contingency**: Use Docker DNS troubleshooting, separate networks if needed

**MEDIUM RISK - Data Migration**:
- **Risk**: PostgreSQL database corruption during multi-database setup
- **Mitigation**: Full backup before changes, test restore procedures, incremental changes
- **Contingency**: Restore from backup, deploy databases on separate instances

**LOW RISK - Certificate Management**:
- **Risk**: TLS certificate expiration or renewal failures
- **Mitigation**: Use Let's Encrypt with auto-renewal, monitoring alerts for expiration
- **Contingency**: Manual certificate renewal procedures documented

### Operational Risks

**HIGH RISK - Compliance Knowledge Gap**:
- **Risk**: Team unfamiliar with GRC workflows and compliance requirements
- **Mitigation**: Comprehensive training, external consultant review, phased rollout
- **Contingency**: Engage compliance consultant for guidance

**MEDIUM RISK - Alert Fatigue**:
- **Risk**: Too many security alerts leading to desensitization
- **Mitigation**: Careful rule tuning, severity levels, aggregation, escalation policies
- **Contingency**: Regular alert review and refinement process

**MEDIUM RISK - Evidence Collection Gaps**:
- **Risk**: Automated evidence collection missing required artifacts
- **Mitigation**: Manual verification of evidence completeness, audit checklist
- **Contingency**: Supplement with manual evidence collection procedures

## Cost Analysis

### Infrastructure Costs (Local/Alpha Phase)

**Hardware/Cloud Resources** (already available):
- Development workstation: $0 (existing, sufficient capacity)
- No additional cloud costs (local Docker deployment)

**Software Licensing**:
- CISO Assistant Community Edition: $0 (AGPLv3)
- Wazuh: $0 (GPLv2, no agent limits)
- All supporting infrastructure: $0 (open source)
- **Total Software Cost**: $0

**Optional Commercial Support** (if needed):
- Wazuh commercial support: ~$1,000/year
- CISO Assistant Pro edition: TBD (not required for core functionality)

**Personnel Time Investment**:
- DevOps engineer (deployment): 40 hours @ $100/hr = $4,000
- Security engineer (configuration): 40 hours @ $125/hr = $5,000
- Compliance specialist (framework setup): 20 hours @ $150/hr = $3,000
- **Total Implementation Cost**: $12,000

**Annual Operational Costs**:
- Monitoring/maintenance: 5 hours/month @ $100/hr = $6,000/year
- Updates and patches: 20 hours/year @ $100/hr = $2,000/year
- Compliance reporting: 10 hours/quarter @ $150/hr = $6,000/year
- **Total Annual Operations**: $14,000/year

**Total Year 1 Cost**: $12,000 (implementation) + $14,000 (operations) = **$26,000**

### Cost Comparison: Open Source vs Commercial

**Commercial SIEM** (Splunk, Datadog):
- Licensing: $20,000-$100,000/year (volume-based)
- Implementation: $15,000-$50,000
- Annual support: Included in licensing
- **Year 1 Total**: $35,000-$150,000

**Commercial GRC** (ServiceNow, LogicGate):
- Licensing: $30,000-$100,000/year
- Implementation: $20,000-$75,000
- Annual support: Included in licensing
- **Year 1 Total**: $50,000-$175,000

**Combined Commercial Stack**: $85,000-$325,000 Year 1

**Open Source Savings**: $59,000-$299,000 in Year 1

### ROI Analysis

**Break-Even Point**: Immediate (Year 1)

**5-Year TCO Comparison**:
- **Open Source Stack**: $26,000 (Y1) + $70,000 (Y2-5 operations) = $96,000
- **Commercial Stack**: $85,000 (Y1) + $400,000 (Y2-5 licensing) = $485,000
- **Savings Over 5 Years**: $389,000 (80% cost reduction)

**Value Beyond Cost Savings**:
- Full data ownership and control (no vendor lock-in)
- Customization capabilities for unique requirements
- Compliance audit readiness from day 1
- Foundation for future certifications (ISO 27001, SOC 2 Type II)
- Enhanced security posture and threat detection

## Next Steps

### Immediate Actions (This Week)

1. **Review and approve this deployment plan** with stakeholders
2. **Create `.env.compliance`** file with secure credentials
3. **Backup current PostgreSQL database** before any changes
4. **Clone CISO Assistant and Wazuh Docker repositories** for reference
5. **Set up staging/testing branch** in Git for compliance stack work

### Week 1 Actions

1. **Create `docker-compose.compliance.yml`** with initial configuration
2. **Generate TLS certificates** for HTTPS endpoints
3. **Configure PostgreSQL databases** for CISO Assistant and Wazuh
4. **Document initial security policies** to load into CISO Assistant
5. **Schedule team training sessions** on GRC and SIEM workflows

### Success Checkpoints

- **Week 2**: CISO Assistant operational with ISO 27001 framework loaded
- **Week 3**: Wazuh SIEM collecting logs from Docker containers and AWS
- **Week 4**: Full integration with Prometheus/Grafana, automated evidence collection
- **Week 6**: Complete compliance stack operational and validated

---

**Prepared by**: AI Coding Agent  
**Review Required**: DevOps Lead, Security Engineer, Compliance Manager  
**Next Review Date**: Prior to Phase 1 deployment
