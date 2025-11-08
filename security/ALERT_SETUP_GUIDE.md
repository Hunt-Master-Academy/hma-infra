# Alert Notification Setup Guide

## Overview

This guide explains how to configure email and webhook notifications for Elastic Security alerts.

**License Requirements**:
- ✅ **Email**: Available in Basic (free) license
- ❌ **Microsoft Teams**: Requires Gold license or higher
- ✅ **Webhook**: Available in Basic license (alternative to Teams)

---

## Email Notifications (Recommended)

### Prerequisites

1. **SMTP Server Access**: Gmail, SendGrid, AWS SES, or corporate SMTP
2. **App Password**: For Gmail, create an app-specific password (not your regular password)

### Gmail Setup (Development)

#### Step 1: Enable 2-Factor Authentication
1. Go to https://myaccount.google.com/security
2. Enable 2-Step Verification

#### Step 2: Create App Password
1. Go to https://myaccount.google.com/apppasswords
2. Select "Mail" and "Other (Custom name)"
3. Name it "HMA Security Alerts"
4. Copy the generated 16-character password

#### Step 3: Configure Email Connector

```bash
# Set environment variables
export EMAIL_USER="your-email@gmail.com"
export EMAIL_PASSWORD="your-16-char-app-password"

# Run configuration script
/home/xbyooki/projects/hma-infra/security/configure-alert-connectors.sh
```

### Production Email Setup (AWS SES)

```bash
# Using AWS SES SMTP
export EMAIL_USER="AKIAIOSFODNN7EXAMPLE"  # AWS SES SMTP username
export EMAIL_PASSWORD="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # AWS SES SMTP password

# Update script with SES settings
# Edit configure-alert-connectors.sh line 66:
# "host": "email-smtp.us-east-1.amazonaws.com"
# "port": 587

/home/xbyooki/projects/hma-infra/security/configure-alert-connectors.sh
```

### SendGrid Setup (Alternative)

```bash
export EMAIL_USER="apikey"  # Literal string "apikey"
export EMAIL_PASSWORD="SG.YOUR_SENDGRID_API_KEY"

# Edit script to use SendGrid:
# "host": "smtp.sendgrid.net"
# "port": 587

/home/xbyooki/projects/hma-infra/security/configure-alert-connectors.sh
```

---

## Webhook Notifications (Teams Alternative - FREE)

Since Teams requires Gold license, use generic webhook connector to send alerts to any endpoint.

### Option 1: Slack Incoming Webhook (Recommended)

#### Setup Slack Webhook
1. Go to https://api.slack.com/messaging/webhooks
2. Create new app → "From scratch"
3. Name: "HMA Security Alerts"
4. Enable Incoming Webhooks
5. Add webhook to channel (e.g., #security-alerts)
6. Copy webhook URL

#### Configure Slack Notifications

```bash
# Create Slack webhook connector manually in Kibana
# Kibana → Stack Management → Connectors → Create connector
# Type: Webhook
# Method: POST
# URL: Your Slack webhook URL
# Headers:
#   Content-Type: application/json
# Body:
{
  "text": "🚨 *HMA Security Alert*",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Rule*: {{context.rule.name}}\n*Severity*: {{context.rule.severity}}\n*Time*: {{date}}\n\n{{context.rule.description}}"
      }
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": {
            "type": "plain_text",
            "text": "View in Kibana"
          },
          "url": "{{context.kibanaBaseUrl}}/app/security/alerts"
        }
      ]
    }
  ]
}
```

### Option 2: Custom Webhook to Your Backend

Create an endpoint in hma-academy-brain to receive alerts:

```typescript
// /hma-academy-brain/src/api/rest/routes/webhookRoutes.ts
router.post('/api/webhooks/security-alert', async (req: Request, res: Response) => {
  const { rule, severity, description, timestamp } = req.body;
  
  // Log to database for audit
  await db.insert('security_alerts', {
    rule_name: rule.name,
    severity,
    description,
    triggered_at: timestamp
  });
  
  // Send notification to admin dashboard via WebSocket
  io.emit('security-alert', {
    rule: rule.name,
    severity,
    message: description
  });
  
  // Forward to Teams/Slack/Discord if configured
  if (process.env.TEAMS_WEBHOOK_URL) {
    await axios.post(process.env.TEAMS_WEBHOOK_URL, {
      title: `Security Alert: ${rule.name}`,
      text: description,
      themeColor: severity === 'high' ? 'FF0000' : 'FFA500'
    });
  }
  
  res.status(200).json({ received: true });
});
```

Then configure webhook connector in Kibana:
- URL: `http://hma-academy-brain:3001/api/webhooks/security-alert`
- Method: POST
- Headers: `Content-Type: application/json`
- Body: See webhook payload below

---

## Manual Configuration via Kibana UI

If you prefer GUI configuration over scripts:

### Step 1: Create Email Connector

1. Open Kibana: http://localhost:5601
2. Go to **Stack Management** → **Connectors**
3. Click **Create connector**
4. Select **Email**
5. Configure:
   - **Name**: HMA Security Alerts - Email
   - **Sender**: security@huntmasteracademy.com
   - **Service**: Other
   - **Host**: smtp.gmail.com
   - **Port**: 587
   - **Secure**: No
   - **Require authentication**: Yes
   - **Username**: your-email@gmail.com
   - **Password**: your-app-password
6. Click **Save**

### Step 2: Attach to Detection Rules

1. Go to **Security** → **Rules**
2. Click on rule (e.g., "HMA - Multiple Failed Admin Login Attempts")
3. Click **Edit rule settings**
4. Scroll to **Actions** section
5. Click **Add action**
6. Select your email connector
7. Configure message:

```
To: security@huntmasteracademy.com, devops@huntmasteracademy.com
Subject: 🚨 HMA Security Alert: {{context.rule.name}}

Security Alert Triggered

Rule: {{context.rule.name}}
Severity: {{context.rule.severity}}
Risk Score: {{context.rule.risk_score}}
Time: {{date}}

Description: {{context.rule.description}}

Alert Count: {{state.signals_count}}

View in Kibana: {{context.kibanaBaseUrl}}/app/security/alerts

---
Hunt Master Academy Security Monitoring System
```

8. Click **Save changes**

### Step 3: Test Notifications

Generate test alert:

```bash
# Trigger failed login rule (5+ attempts in 10 min)
for i in {1..6}; do
  curl -X POST http://localhost:3001/api/admin/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test-attack@evil.com","password":"wrongpass"}'
  sleep 2
done

# Check for email within 5-10 minutes (rule interval)
```

---

## Alert Action Templates

### High Severity Email Template

```
Subject: 🚨 URGENT: HMA Security Alert [HIGH] - {{context.rule.name}}

⚠️ CRITICAL SECURITY ALERT ⚠️

Rule: {{context.rule.name}}
Severity: HIGH
Risk Score: {{context.rule.risk_score}}
Triggered: {{date}}

DESCRIPTION:
{{context.rule.description}}

ALERT DETAILS:
- Total Alerts: {{state.signals_count}}
- Environment: Production
- System: Hunt Master Academy

IMMEDIATE ACTIONS REQUIRED:
1. Review alert details in Kibana
2. Investigate source of activity
3. Take containment measures if confirmed threat
4. Update incident log

🔗 View Full Details: {{context.kibanaBaseUrl}}/app/security/alerts
🔗 Security Dashboard: {{context.kibanaBaseUrl}}/app/security/overview

---
This is an automated alert from HMA Security Operations Center.
Response time SLA: 15 minutes for HIGH severity alerts.
```

### Medium Severity Email Template

```
Subject: ⚠️ HMA Security Alert [MEDIUM] - {{context.rule.name}}

Security Alert Notification

Rule: {{context.rule.name}}
Severity: MEDIUM
Risk Score: {{context.rule.risk_score}}
Time: {{date}}

Description: {{context.rule.description}}

Alert Count: {{state.signals_count}}

ACTION REQUIRED:
Review this alert within 1 hour and determine if investigation needed.

View Details: {{context.kibanaBaseUrl}}/app/security/alerts

---
HMA Security Monitoring
```

### Slack Webhook Body Template

```json
{
  "text": "🚨 HMA Security Alert",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "🚨 Security Alert: {{context.rule.name}}"
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Severity:*\n{{context.rule.severity}}"
        },
        {
          "type": "mrkdwn",
          "text": "*Risk Score:*\n{{context.rule.risk_score}}"
        },
        {
          "type": "mrkdwn",
          "text": "*Alerts:*\n{{state.signals_count}}"
        },
        {
          "type": "mrkdwn",
          "text": "*Time:*\n{{date}}"
        }
      ]
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Description:*\n{{context.rule.description}}"
      }
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": {
            "type": "plain_text",
            "text": "View in Kibana"
          },
          "style": "danger",
          "url": "{{context.kibanaBaseUrl}}/app/security/alerts"
        }
      ]
    }
  ]
}
```

---

## Testing Notifications

### Test Email Connector

```bash
# In Kibana UI: Stack Management → Connectors → Your Email Connector → Test
# Or via API:

curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  -X POST "http://localhost:5601/api/actions/connector/CONNECTOR_ID/_execute" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d '{
    "params": {
      "to": ["security@huntmasteracademy.com"],
      "subject": "Test Alert from HMA Security",
      "message": "This is a test email to verify alert notifications are working."
    }
  }'
```

### Generate Real Alert

```bash
# Trigger "Multiple Failed Admin Login Attempts" rule
cd /home/xbyooki/projects/hma-infra/security
./test-security-rules.sh failed-logins

# Or manually:
for i in {1..6}; do
  curl -X POST http://localhost:3001/api/admin/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"attacker-$(date +%s)@test.com\",\"password\":\"wrong\"}"
  sleep 1
done

echo "Alert should trigger within 5-10 minutes (rule interval: 5m)"
```

---

## Troubleshooting

### Email Not Sending

**Check connector configuration:**
```bash
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  "http://localhost:5601/api/actions/connectors" \
  -H 'kbn-xsrf: true' | jq '.[] | select(.name | contains("Email"))'
```

**Common issues:**
- Gmail: Use app password, not regular password
- Port blocked: Try port 465 (SSL) instead of 587 (TLS)
- Authentication: Verify username/password are correct
- Sender address: Some SMTP servers require sender to match authenticated user

**Test SMTP connection:**
```bash
# Install swaks (SMTP test tool)
sudo apt-get install swaks

# Test connection
swaks --to security@huntmasteracademy.com \
  --from your-email@gmail.com \
  --server smtp.gmail.com:587 \
  --auth LOGIN \
  --auth-user your-email@gmail.com \
  --auth-password "your-app-password" \
  --tls
```

### Rules Not Triggering

**Check rule status:**
```bash
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  "http://localhost:5601/api/detection_engine/rules/_find?filter=alert.attributes.tags:HMA" \
  -H 'kbn-xsrf: true' | jq '.data[] | {name: .name, enabled: .enabled, last_success: .execution_status.last_execution_date}'
```

**Verify APM data is flowing:**
```bash
# Check for matching events in Elasticsearch
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  "http://localhost:9200/.ds-traces-apm-default-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"term": {"service.name": "hma-academy-brain"}},
          {"term": {"http.response.status_code": 401}}
        ]
      }
    },
    "size": 1
  }' | jq '.hits.total.value'
```

### Webhook Connection Failed

**Check endpoint is accessible from container:**
```bash
docker exec hma-academy-brain curl -I http://your-webhook-url
```

**Verify webhook payload format matches expected structure**

---

## Next Steps

1. **Choose notification method**:
   - Email (recommended for production)
   - Slack webhook (best for teams)
   - Custom backend webhook (most flexible)

2. **Configure credentials** using environment variables

3. **Run setup script**:
   ```bash
   /home/xbyooki/projects/hma-infra/security/configure-alert-connectors.sh
   ```

4. **Test notifications** with simulated attacks

5. **Create escalation policy**:
   - HIGH severity → Email + Slack + SMS (PagerDuty)
   - MEDIUM severity → Email + Slack
   - LOW severity → Email only

6. **Document response procedures** for each alert type

---

## References

- Configuration Script: `/hma-infra/security/configure-alert-connectors.sh`
- Connector Definitions: `/hma-infra/security/alert-connectors.json`
- Detection Rules: `/hma-infra/security/detection-rules.json`
- Kibana Actions API: https://www.elastic.co/guide/en/kibana/current/actions-api.html
