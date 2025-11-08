# 🚀 HMA Security & Observability Quick Start

**Complete Stack Status**: ✅ ALL OPERATIONAL

---

## 📋 What's Deployed

| Service | Purpose | Access | Status |
|---------|---------|--------|--------|
| **Elastic APM** | App monitoring | http://localhost:5601/app/apm | ✅ Operational |
| **Elastic Security** | Threat detection | http://localhost:5601/app/security/rules | ✅ 10 rules active |
| **Kibana** | UI & Dashboards | http://localhost:5601 | ✅ Operational |
| **Mattermost** | Team chat & alerts | http://localhost:8065 | ✅ Operational |
| **CISO Assistant** | GRC compliance | https://localhost:8443 | ✅ Operational |

---

## ⚡ Quick Actions

### View Application Performance
```bash
open http://localhost:5601/app/apm
# Services: hma-academy-brain, hma-academy-web
# Backend: 1,019+ traces | Frontend: 241+ RUM events
```

### View Security Alerts
```bash
open http://localhost:5601/app/security/alerts
# 10 detection rules monitoring authentication, admin actions, infrastructure
```

### Access Team Chat
```bash
open http://localhost:8065
# First time: Create admin account
# Then: Set up #security-alerts channel and webhook
```

---

## 🔔 Enable Alert Notifications (5-Minute Setup)

### Option 1: Mattermost Webhooks (Recommended - FREE)

**Step 1**: Set up Mattermost
```bash
# 1. Open http://localhost:8065
# 2. Create account (use admin@huntmasteracademy.com)
# 3. Create channel: #security-alerts
# 4. Go to Main Menu → Integrations → Incoming Webhooks
# 5. Create webhook, copy URL
```

**Step 2**: Configure in Kibana
```bash
# 1. Open http://localhost:5601
# 2. Stack Management → Connectors → Create → Webhook
# 3. Name: HMA Mattermost Alerts
# 4. URL: http://hma_mattermost:8065/hooks/YOUR_WEBHOOK_ID
# 5. Method: POST
# 6. Header: Content-Type: application/json
# 7. Body: See /hma-infra/security/MATTERMOST_SETUP.md for template
```

**Step 3**: Attach to Rules
```bash
# 1. Security → Rules → Select rule
# 2. Edit → Actions → Add action
# 3. Select your Mattermost connector
# 4. Configure message template
# 5. Save
```

### Option 2: Email via External Service (Requires Gold License)

Email connectors in Elastic require Gold license ($$$). Instead, use Mattermost which:
- ✅ Sends its own email notifications (already configured)
- ✅ Receives webhooks (FREE in Elastic Basic)
- ✅ Can forward to external services via integrations

---

## 🧪 Test the System

### 1. Generate Security Events
```bash
cd /home/xbyooki/projects/hma-infra/security

# Test failed login detection
./test-security-rules.sh failed-logins

# Test all automated rules
./test-security-rules.sh all
```

### 2. Check for Alerts
```bash
# Wait 5-10 minutes (rule execution interval)

# View in Kibana
open http://localhost:5601/app/security/alerts

# View in Mattermost (if webhook configured)
open http://localhost:8065
```

### 3. Verify APM Data
```bash
# Check metrics in Elasticsearch
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  "http://localhost:9200/_cat/indices/*apm*?v&h=index,docs.count"
```

---

## 🔐 Credentials

### Elasticsearch/Kibana
```
URL: http://localhost:5601 (HTTP)
URL: https://localhost:8444 (HTTPS via Caddy)
User: elastic
Password: HMA_Elastic_Dev_Pass_2025!
```

### Mattermost
```
URL: http://localhost:8065
User: (create during first login)
Suggested: admin@huntmasteracademy.com
Password: (choose secure password)
```

### CISO Assistant
```
URL: https://localhost:8443
User: (set during setup)
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `/hma-infra/security/DEPLOYMENT_SUMMARY.md` | Complete deployment overview |
| `/hma-infra/security/MATTERMOST_SETUP.md` | Mattermost configuration guide |
| `/hma-infra/security/ALERT_SETUP_GUIDE.md` | Email/webhook setup (detailed) |
| `/hma-infra/security/README.md` | Security rules documentation |
| `/hma-infra/security/test-security-rules.sh` | Automated testing script |
| `/hma-infra/security/detection-rules.json` | 10 security rule definitions |

---

## 🎯 Next Steps

1. **Complete Mattermost Setup** (10 minutes)
   - Create admin account
   - Set up #security-alerts channel
   - Generate webhook URL
   - Configure webhook in Kibana

2. **Attach Webhooks to Critical Rules** (5 minutes)
   - HMA - Multiple Failed Admin Login Attempts
   - HMA - Unauthorized Admin Access Attempt
   - HMA - Database Connection Failures

3. **Test Alert Flow** (5 minutes)
   - Run `./test-security-rules.sh failed-logins`
   - Wait 5-10 minutes
   - Check Mattermost for alert message

4. **Invite Team Members** (5 minutes)
   - Add developers to Mattermost
   - Create additional channels (#devops, #general)
   - Share access credentials

5. **Customize Dashboards** (Optional)
   - Create Kibana dashboard for key metrics
   - Set up Grafana visualizations
   - Configure custom alert thresholds

---

## 🆘 Troubleshooting

### Services Not Running
```bash
cd /home/xbyooki/projects/hma-infra/docker

# Check all services
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Start compliance stack (Elasticsearch, Kibana, APM, CISO)
docker-compose -f docker-compose.yml -f docker-compose.compliance.yml up -d

# Start Mattermost
docker-compose -f docker-compose.mattermost.yml up -d
```

### Can't Access Kibana
```bash
# Check container
docker logs hma_kibana --tail 50

# Verify Elasticsearch is healthy
curl -u elastic:HMA_Elastic_Dev_Pass_2025! http://localhost:9200/_cluster/health
```

### Mattermost Not Loading
```bash
# Check logs
docker logs hma_mattermost --tail 50

# Restart
docker restart hma_mattermost

# Verify API
curl http://localhost:8065/api/v4/system/ping
```

### Security Rules Not Triggering
```bash
# Check rule status
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  "http://localhost:5601/api/detection_engine/rules/_find?filter=alert.attributes.tags:HMA" \
  -H 'kbn-xsrf: true' | jq '.data[] | {name: .name, enabled: .enabled}'

# Verify APM data is flowing
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  "http://localhost:9200/.ds-traces-apm-default-*/_count"
```

---

## 📞 Support

- **Kibana UI**: http://localhost:5601
- **Mattermost**: http://localhost:8065  
- **Documentation**: `/home/xbyooki/projects/hma-infra/security/`
- **Test Scripts**: `/home/xbyooki/projects/hma-infra/security/test-security-rules.sh`

---

## 🎉 You're All Set!

Your Hunt Master Academy security and observability stack is fully deployed and ready to use. The system is now monitoring your application 24/7 for:

- ✅ Application performance issues
- ✅ Security threats and attacks
- ✅ Infrastructure failures
- ✅ Admin action audit trail
- ✅ Compliance requirements

**Complete Mattermost setup to start receiving real-time alerts!**

---

**Last Updated**: November 8, 2025  
**Status**: All services operational  
**Monitoring**: 1,260+ APM traces, 10 security rules active
