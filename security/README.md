# [20251108-SECURITY-002] Elastic Security Configuration for HMA

## Detection Rules

### Rule Categories

#### 1. Authentication & Authorization (High Priority)
- **Multiple Failed Admin Login Attempts** (High, Score: 73)
  - Threshold: 5 failed attempts from same IP in 10 minutes
  - Indicates: Potential brute force attack
  - Action: Review source IP, consider temporary ban

- **Unauthorized Admin Access Attempt** (High, Score: 68)
  - Detects: 403 Forbidden on `/api/admin/*` endpoints
  - Indicates: Privilege escalation attempt
  - Action: Review user account, audit permissions

- **Failed Authentication Spike** (Medium, Score: 55)
  - Threshold: 20 failed auth attempts from same IP in 10 minutes
  - Indicates: Distributed attack or credential stuffing
  - Action: Rate limiting review, CAPTCHA consideration

#### 2. Admin Actions (Audit Trail)
- **Admin Account Deletion** (Medium, Score: 47)
  - Monitors: User deletion by admin accounts
  - Purpose: Compliance audit trail
  - Action: Review deletion reason, verify authorization

- **Suspicious Credit Manipulation** (Medium, Score: 63)
  - Threshold: 10+ credit adjustments by same admin in 10 minutes
  - Indicates: Potential abuse or automation
  - Action: Review admin actions log, verify legitimacy

- **Subscription Plan Changes** (Low, Score: 21)
  - Monitors: All subscription plan modifications
  - Purpose: Financial audit trail
  - Action: Log for compliance, no immediate action needed

#### 3. Infrastructure & Performance
- **Database Connection Failures** (Medium, Score: 55)
  - Threshold: 5+ connection failures in 10 minutes
  - Indicates: Database outage or network issues
  - Action: Check PostgreSQL health, restart if needed

- **High Error Rate on Critical Endpoints** (Medium, Score: 47)
  - Threshold: 10+ 5xx errors on critical paths in 10 minutes
  - Endpoints: `/api/auth/*`, `/api/courses/*`, `/api/billing/*`
  - Action: Check service logs, investigate root cause

- **MinIO Storage Access Anomaly** (Medium, Score: 42)
  - Detects: 403/500 errors on storage endpoints
  - Indicates: Permission issues or storage failure
  - Action: Verify MinIO health, check bucket policies

- **Slow Transaction Performance** (Low, Score: 21)
  - Threshold: 5+ transactions exceeding 5 seconds in 10 minutes
  - Indicates: Performance degradation or DoS
  - Action: Review APM traces, optimize queries

## Alert Actions & Notifications

### Email Notifications (Recommended - FREE)

**Status**: ✅ Script ready, requires SMTP configuration

**Setup Guide**: See `ALERT_SETUP_GUIDE.md` for detailed instructions

**Quick Start**:
```bash
# Set your email credentials
export EMAIL_USER="your-email@gmail.com"
export EMAIL_PASSWORD="your-16-char-app-password"

# Run configuration script
/home/xbyooki/projects/hma-infra/security/configure-alert-connectors.sh
```

**Supported SMTP Providers**:
- Gmail (with app password)
- AWS SES
- SendGrid
- Office 365
- Custom SMTP server

**Email Template (High Severity)**:
```
Subject: 🚨 URGENT: HMA Security Alert [HIGH] - {{rule.name}}

Rule: {{rule.name}}
Severity: HIGH
Risk Score: {{rule.risk_score}}
Time: {{date}}

Description: {{rule.description}}
Alert Count: {{state.signals_count}}

View Details: {{kibanaBaseUrl}}/app/security/alerts
```

### Slack/Webhook Integration (FREE Alternative to Teams)

**Microsoft Teams**: ❌ Requires Gold license (not available in Basic/Free)

**Recommended Alternative**: Use Slack or generic webhook connector (available in Basic license)

**Slack Setup**:
1. Create Slack incoming webhook
2. Configure in Kibana: Stack Management → Connectors → Webhook
3. Attach to high-severity rules

**Custom Webhook**: Send alerts to your own backend endpoint for processing

**Setup Guide**: See `ALERT_SETUP_GUIDE.md` section "Webhook Notifications"

### PagerDuty Integration (Production)

**Status**: 🚧 Future enhancement for Production environment

**Use Case**: Critical alerts requiring immediate on-call response

**Configuration**:
```json
{
  "service_key": "{{PAGERDUTY_SERVICE_KEY}}",
  "severity": "{{rule.severity}}",
  "on_call_rotation": "hma-devops"
}
```

## Rule Management

### Viewing Rules
```bash
# Access Kibana Security
http://localhost:5601/app/security/rules
https://localhost:8444/app/security/rules

# List all HMA rules via API
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  "http://localhost:5601/api/detection_engine/rules/_find?filter=alert.attributes.tags:HMA" \
  -H 'kbn-xsrf: true' | jq '.data[] | {name: .name, enabled: .enabled, severity: .severity}'
```

### Updating Rules
```bash
# Re-import updated rules (overwrites existing)
/home/xbyooki/projects/hma-infra/security/import-detection-rules.sh

# Enable/disable specific rule
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  -X PATCH "http://localhost:5601/api/detection_engine/rules" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d '{"id": "RULE_ID", "enabled": false}'
```

### Testing Rules
```bash
# Run all automated security rule tests
/home/xbyooki/projects/hma-infra/security/test-security-rules.sh all

# Test specific rule
/home/xbyooki/projects/hma-infra/security/test-security-rules.sh failed-logins

# Available tests:
# - failed-logins: Test failed admin login detection
# - unauthorized: Test unauthorized access detection  
# - auth-spike: Test authentication spike detection
# - normal: Generate baseline normal traffic
```

## Integration with CISO Assistant

### Compliance Mapping
- **Admin Account Deletion** → GDPR Right to Erasure audit
- **Subscription Plan Changes** → Financial audit trail
- **Unauthorized Access Attempts** → Security incident log
- **Database Connection Failures** → Availability SLA tracking

### Export Alerts to CISO Assistant
```bash
# Future: Automated sync between Elastic Security and CISO Assistant
# Will use Elasticsearch -> Logstash -> CISO Assistant API pipeline
```

## Monitoring Dashboard

### Key Metrics
1. **Security Alerts (Last 24h)**
   - High severity: Target 0
   - Medium severity: Target < 5
   - Low severity: Informational only

2. **Most Triggered Rules**
   - Identify patterns
   - Tune thresholds if excessive false positives

3. **Response Times**
   - Time from alert to investigation
   - Time from investigation to resolution

## Maintenance

### Weekly Tasks
- [ ] Review high-severity alerts
- [ ] Check for false positives
- [ ] Update rule thresholds if needed
- [ ] Verify alert notifications working

### Monthly Tasks
- [ ] Audit admin actions log
- [ ] Review detection rule effectiveness
- [ ] Update rules for new attack patterns
- [ ] Export alerts to compliance reports

### Quarterly Tasks
- [ ] Full security audit
- [ ] Penetration testing
- [ ] Rule coverage review
- [ ] Integration with threat intelligence feeds

## Access Control

### Who Can View Alerts
- **Security Team**: Full access to all alerts
- **DevOps Team**: Infrastructure alerts only
- **Admin Team**: Admin action audit logs
- **Compliance Officer**: Full read-only access

### Kibana Role Mapping
```json
{
  "security_analyst": {
    "privileges": ["all"],
    "indices": [".alerts-security.*"],
    "applications": ["kibana:.security"]
  },
  "devops": {
    "privileges": ["read"],
    "indices": [".alerts-security.*"],
    "query": "tags:Infrastructure OR tags:Performance"
  }
}
```

## Documentation
- Detection Rules: `/hma-infra/security/detection-rules.json`
- Import Script: `/hma-infra/security/import-detection-rules.sh`
- Integration Config: `/hma-docs/deployment/integration-configuration.md`
