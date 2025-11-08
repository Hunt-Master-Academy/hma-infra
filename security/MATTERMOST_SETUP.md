# Mattermost Setup & Webhook Configuration for Security Alerts

## Overview

Mattermost is deployed as a self-hosted Slack alternative for HMA team communication and security alert notifications.

**Why Mattermost Instead of Slack/Teams?**
- ✅ FREE (no license restrictions like Elastic connectors)
- ✅ Self-hosted (data stays on your infrastructure)
- ✅ Incoming webhooks support (for Elastic Security alerts)
- ✅ Integrated with existing Hostinger SMTP for email notifications
- ✅ Team chat, channels, direct messages
- ✅ Mobile apps available

---

## Access Information

- **URL**: http://localhost:8065
- **Container**: `hma_mattermost`
- **Database**: `hma_mattermost_db` (PostgreSQL 16)
- **Email**: Configured with info@huntmasteracademy.com (Hostinger SMTP)

---

## Initial Setup (First Time)

### Step 1: Create Admin Account

1. Open browser: http://localhost:8065
2. Click "Create an account"
3. Fill in details:
   - **Email**: `admin@huntmasteracademy.com` (or your email)
   - **Username**: `hma-admin`
   - **Password**: `hu8bhy6nHU*BHY^N` (or choose your own)
4. Click "Create Account"
5. Create your first team: "HMA Operations"

### Step 2: Create Security Alerts Channel

1. After login, click "+ Create new channel"
2. Name: `security-alerts`
3. Purpose: "Automated security alerts from Elastic Security"
4. Type: Public (or Private if preferred)
5. Click "Create Channel"

### Step 3: Enable Incoming Webhooks

1. Click profile icon → **System Console**
2. Navigate to **Integrations** → **Integration Management**
3. Verify these are enabled:
   - ✅ Enable Incoming Webhooks
   - ✅ Enable Outgoing Webhooks
   - ✅ Enable Custom Integrations
   - ✅ Enable integrations to override usernames
   - ✅ Enable integrations to override profile picture icons
4. Click "Save"

### Step 4: Create Incoming Webhook for Security Alerts

1. Go back to your team
2. Click **Main Menu** (9 dots) → **Integrations**
3. Click **Incoming Webhooks** → **Add Incoming Webhook**
4. Configure:
   - **Title**: HMA Security Alerts
   - **Description**: Receives automated security alerts from Elastic Security
   - **Channel**: security-alerts
   - **Lock to this channel**: No (allows flexibility)
5. Click "Save"
6. **Copy the webhook URL** - you'll need this for Kibana configuration!
   - Example: `http://hma_mattermost:8065/hooks/abc123xyz456`

---

## Configure Elastic Security to Send Alerts to Mattermost

### Option 1: Via Kibana UI (Recommended)

1. Open Kibana: http://localhost:5601
2. Go to **Stack Management** → **Connectors**
3. Click **Create connector**
4. Select **Webhook**
5. Configure:
   - **Name**: HMA Mattermost Alerts
   - **URL**: `http://hma_mattermost:8065/hooks/YOUR_WEBHOOK_ID`
   - **Method**: POST
   - **Headers**:
     ```
     Content-Type: application/json
     ```
   - **Body** (Mattermost message format):
```json
{
  "text": "🚨 **HMA Security Alert**",
  "username": "Security Bot",
  "icon_url": "https://www.elastic.co/apple-touch-icon.png",
  "attachments": [
    {
      "color": "#FF0000",
      "title": "{{context.rule.name}}",
      "text": "**Severity**: {{context.rule.severity}}\\n**Risk Score**: {{context.rule.risk_score}}\\n**Time**: {{date}}\\n\\n{{context.rule.description}}\\n\\n**Alert Count**: {{state.signals_count}}",
      "fields": [
        {
          "short": true,
          "title": "Severity",
          "value": "{{context.rule.severity}}"
        },
        {
          "short": true,
          "title": "Risk Score",
          "value": "{{context.rule.risk_score}}"
        }
      ],
      "actions": [
        {
          "name": "View in Kibana",
          "integration": {
            "url": "{{context.kibanaBaseUrl}}/app/security/alerts"
          }
        }
      ]
    }
  ]
}
```
6. Click **Save**

### Option 2: Automated Script

Create and run this script:

```bash
#!/bin/bash
# Configure Mattermost webhook connector in Kibana

KIBANA_URL="http://localhost:5601"
ELASTIC_USER="elastic"
ELASTIC_PASSWORD="HMA_Elastic_Dev_Pass_2025!"
MATTERMOST_WEBHOOK_URL="http://hma_mattermost:8065/hooks/YOUR_WEBHOOK_ID_HERE"

# Create webhook connector
curl -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
  -X POST "$KIBANA_URL/api/actions/connector" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "HMA Mattermost Security Alerts",
    "connector_type_id": ".webhook",
    "config": {
      "url": "'"$MATTERMOST_WEBHOOK_URL"'",
      "method": "post",
      "headers": {
        "Content-Type": "application/json"
      }
    },
    "secrets": {}
  }'
```

---

## Attach Webhook to Security Rules

### Via Kibana UI

1. Go to **Security** → **Rules**
2. Click on a rule (e.g., "HMA - Multiple Failed Admin Login Attempts")
3. Click **Edit rule settings**
4. Scroll to **Actions** section
5. Click **Add action**
6. Select **HMA Mattermost Alerts** (your webhook connector)
7. Configure message:

**Action frequency**: For each alert

**Message body**:
```json
{
  "text": "🚨 **Security Alert: {{context.rule.name}}**",
  "username": "HMA Security Bot",
  "icon_emoji": ":warning:",
  "attachments": [
    {
      "color": "{{#eq context.rule.severity "high"}}#FF0000{{else}}#FFA500{{/eq}}",
      "title": "{{context.rule.name}}",
      "text": "{{context.rule.description}}",
      "fields": [
        {
          "short": true,
          "title": "Severity",
          "value": "{{context.rule.severity}}"
        },
        {
          "short": true,
          "title": "Risk Score",
          "value": "{{context.rule.risk_score}}"
        },
        {
          "short": true,
          "title": "Alerts",
          "value": "{{state.signals_count}}"
        },
        {
          "short": true,
          "title": "Time",
          "value": "{{date}}"
        }
      ]
    }
  ]
}
```

8. Click **Save changes**
9. Repeat for other high-priority rules

---

## Test Mattermost Notifications

### Method 1: Manual Webhook Test

```bash
# Replace with your actual webhook URL
WEBHOOK_URL="http://localhost:8065/hooks/YOUR_WEBHOOK_ID"

# Send test message
curl -X POST "$WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "🧪 Test Alert from HMA Security System",
    "username": "Security Bot",
    "icon_emoji": ":shield:",
    "attachments": [
      {
        "color": "#00FF00",
        "title": "System Test",
        "text": "This is a test message to verify Mattermost webhook integration is working.",
        "fields": [
          {
            "short": true,
            "title": "Status",
            "value": "✅ Operational"
          },
          {
            "short": true,
            "title": "Timestamp",
            "value": "'"$(date)"'"
          }
        ]
      }
    ]
  }'
```

### Method 2: Trigger Real Security Alert

```bash
# Run automated security tests
cd /home/xbyooki/projects/hma-infra/security
./test-security-rules.sh failed-logins

# Wait 5-10 minutes for rule to execute
# Check #security-alerts channel in Mattermost
```

---

## Mattermost Message Formats

### High Severity Alert Template

```json
{
  "text": "🚨 **CRITICAL SECURITY ALERT**",
  "username": "HMA Security Bot",
  "icon_emoji": ":rotating_light:",
  "attachments": [
    {
      "color": "#FF0000",
      "title": "Multiple Failed Admin Login Attempts",
      "text": "Detected 6 failed login attempts to admin portal from same IP within 10 minutes. Potential brute force attack in progress.",
      "fields": [
        {
          "short": true,
          "title": "Severity",
          "value": "HIGH"
        },
        {
          "short": true,
          "title": "Risk Score",
          "value": "73"
        },
        {
          "short": false,
          "title": "Action Required",
          "value": "Review source IP and consider temporary ban"
        }
      ],
      "actions": [
        {
          "name": "View in Kibana",
          "integration": {
            "url": "http://localhost:5601/app/security/alerts"
          }
        }
      ]
    }
  ]
}
```

### Medium Severity Alert Template

```json
{
  "text": "⚠️ Security Alert",
  "username": "HMA Security Bot",
  "icon_emoji": ":warning:",
  "attachments": [
    {
      "color": "#FFA500",
      "title": "Suspicious Credit Manipulation",
      "text": "Detected 12 credit adjustments by same admin in 10 minutes.",
      "fields": [
        {
          "short": true,
          "title": "Severity",
          "value": "MEDIUM"
        },
        {
          "short": true,
          "title": "Risk Score",
          "value": "63"
        }
      ]
    }
  ]
}
```

---

## Additional Mattermost Configuration

### Email Notifications (Already Configured)

Mattermost is pre-configured to use Hostinger SMTP:
- **From**: info@huntmasteracademy.com
- **Server**: smtp.hostinger.com:465 (SSL)

Users will receive email notifications for:
- Direct messages
- Channel mentions (@username or @channel)
- Missed messages while offline

### Invite Team Members

1. Go to **Main Menu** → **Invite People**
2. Share invite link or enter email addresses
3. New users will receive email invitation

### Create Additional Channels

Recommended channels:
- `#general` - Team discussions
- `#security-alerts` - Automated security notifications
- `#devops` - Infrastructure and deployment updates
- `#development` - Code and feature discussions
- `#support` - Customer support coordination

---

## Integration with HMA Backend (Future Enhancement)

You can send custom notifications from `hma-academy-brain` to Mattermost:

```typescript
// /hma-academy-brain/src/services/mattermostService.ts
import axios from 'axios';

export class MattermostService {
  private webhookUrl = process.env.MATTERMOST_WEBHOOK_URL || '';

  async sendAlert(params: {
    title: string;
    message: string;
    severity: 'high' | 'medium' | 'low';
    fields?: Array<{ title: string; value: string; short?: boolean }>;
  }) {
    if (!this.webhookUrl) {
      console.warn('Mattermost webhook URL not configured');
      return;
    }

    const color = {
      high: '#FF0000',
      medium: '#FFA500',
      low: '#0000FF'
    }[params.severity];

    const icon = {
      high: ':rotating_light:',
      medium: ':warning:',
      low: ':information_source:'
    }[params.severity];

    await axios.post(this.webhookUrl, {
      text: `${icon} **${params.title}**`,
      username: 'HMA Backend',
      attachments: [{
        color,
        text: params.message,
        fields: params.fields || []
      }]
    });
  }
}

// Usage example:
const mattermost = new MattermostService();
await mattermost.sendAlert({
  title: 'Subscription Purchased',
  message: 'User john@example.com purchased Elite subscription',
  severity: 'low',
  fields: [
    { title: 'User', value: 'john@example.com', short: true },
    { title: 'Plan', value: 'Elite', short: true },
    { title: 'Amount', value: '$99.99', short: true }
  ]
});
```

---

## Mobile Apps

Mattermost has official mobile apps for iOS and Android:

1. Download from App Store or Google Play
2. Search for "Mattermost"
3. Connect to server: `http://YOUR_SERVER_IP:8065`
4. Login with your credentials
5. Receive push notifications for alerts on mobile

---

## Troubleshooting

### Can't Access Mattermost UI

```bash
# Check container status
docker ps | grep mattermost

# Check logs
docker logs hma_mattermost --tail 50

# Verify port is accessible
curl -I http://localhost:8065
```

### Webhook Not Receiving Messages

1. Verify webhook URL is correct (should include `/hooks/` path)
2. Check webhook is enabled in Integrations settings
3. Test with manual curl command (see test section above)
4. Check Mattermost logs for errors:
   ```bash
   docker logs hma_mattermost | grep webhook
   ```

### SMTP Errors in Logs

The SMTP connection error during startup is expected - Mattermost tests the connection but it doesn't block functionality. Email notifications will still work when actually needed.

---

## Management Commands

```bash
# Start Mattermost
cd /home/xbyooki/projects/hma-infra/docker
docker-compose -f docker-compose.mattermost.yml up -d

# Stop Mattermost
docker-compose -f docker-compose.mattermost.yml down

# View logs
docker logs hma_mattermost -f

# Restart
docker-compose -f docker-compose.mattermost.yml restart

# Access database
docker exec -it hma_mattermost_db psql -U mmuser -d mattermost
```

---

## Security Best Practices

1. **Change Default Passwords**: Update admin password after first login
2. **Enable 2FA**: Configure in System Console → Security
3. **Restrict Signups**: Disable open signups, use invite-only
4. **Regular Updates**: Keep Mattermost updated for security patches
5. **Backup Database**: Regular backups of `hma_mattermost_db_data` volume

---

## Next Steps

1. ✅ Mattermost is running
2. ⏳ Complete initial setup (create admin account)
3. ⏳ Create #security-alerts channel
4. ⏳ Generate incoming webhook URL
5. ⏳ Configure webhook connector in Kibana
6. ⏳ Attach webhook to high-priority security rules
7. ⏳ Test with simulated security event

---

**Documentation**: 
- Mattermost Docs: https://docs.mattermost.com/
- Incoming Webhooks: https://docs.mattermost.com/developer/webhooks-incoming.html
- Message Formatting: https://docs.mattermost.com/collaborate/format-messages.html
