# Free Alternative to Paid Elastic Connectors

## The Problem

Elastic Basic (free) license only supports TWO connector types:
- ✅ **Index** - Write to Elasticsearch index
- ✅ **Server log** - Write to Kibana logs
- ❌ **Email** - Requires Gold license
- ❌ **Webhook** - Requires Gold license  
- ❌ **Slack** - Requires Gold license
- ❌ **Teams** - Requires Gold license

## The Solution: Custom Alert Pipeline

Since we can't use webhooks directly, we'll use the **Index connector** to write alerts to a custom Elasticsearch index, then pull them into Mattermost via a backend service.

---

## Architecture

```
Elastic Detection Rule
    ↓
Index Connector (FREE)
    ↓
Custom ES Index: hma-security-alerts
    ↓
Backend Service (Node.js polling)
    ↓
Mattermost Incoming Webhook
    ↓
#security-alerts channel
```

---

## Step 1: Configure Index Connector in Kibana

### Via UI

1. Open Kibana: http://localhost:5601
2. **Stack Management** → **Connectors**
3. **Create connector** → **Index**
4. Configure:
   - **Name**: HMA Security Alerts Index
   - **Index**: `hma-security-alerts`
   - **Execution time field**: `@timestamp`
   - **Document ID**: (leave empty for auto-generation)
5. **Save**

### Via API

```bash
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  -X POST "http://localhost:5601/api/actions/connector" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "HMA Security Alerts Index",
    "connector_type_id": ".index",
    "config": {
      "index": "hma-security-alerts",
      "executionTimeField": "@timestamp"
    },
    "secrets": {}
  }'
```

---

## Step 2: Attach Index Connector to Security Rules

1. **Security** → **Rules** → Select a rule
2. **Edit rule settings** → **Actions**
3. **Add action** → Select **HMA Security Alerts Index**
4. Configure document:

```json
{
  "rule_id": "{{context.rule.id}}",
  "rule_name": "{{context.rule.name}}",
  "severity": "{{context.rule.severity}}",
  "risk_score": "{{context.rule.risk_score}}",
  "description": "{{context.rule.description}}",
  "alert_count": "{{state.signals_count}}",
  "triggered_at": "{{date}}",
  "kibana_url": "{{context.kibanaBaseUrl}}/app/security/alerts"
}
```

5. **Save**

---

## Step 3: Create Alert Polling Service

Create a Node.js service in `hma-academy-brain` to poll for new alerts and forward to Mattermost:

```typescript
// /hma-academy-brain/src/services/alertPollingService.ts
import { Client } from '@elastic/elasticsearch';
import axios from 'axios';

export class AlertPollingService {
  private esClient: Client;
  private mattermostWebhook: string;
  private lastCheckTime: Date;
  private pollInterval: number = 60000; // 1 minute

  constructor() {
    this.esClient = new Client({
      node: 'http://hma_elasticsearch:9200',
      auth: {
        username: 'elastic',
        password: process.env.ELASTIC_PASSWORD || 'HMA_Elastic_Dev_Pass_2025!'
      }
    });
    this.mattermostWebhook = process.env.MATTERMOST_WEBHOOK_URL || '';
    this.lastCheckTime = new Date();
  }

  async start() {
    console.log('✅ Alert polling service started');
    setInterval(() => this.pollAlerts(), this.pollInterval);
  }

  private async pollAlerts() {
    try {
      // Query for new alerts since last check
      const response = await this.esClient.search({
        index: 'hma-security-alerts',
        body: {
          query: {
            range: {
              '@timestamp': {
                gt: this.lastCheckTime.toISOString()
              }
            }
          },
          sort: [{ '@timestamp': 'asc' }]
        }
      });

      if (response.hits.hits.length > 0) {
        console.log(`📊 Found ${response.hits.hits.length} new alerts`);

        for (const hit of response.hits.hits) {
          await this.sendToMattermost(hit._source);
        }

        // Update last check time
        this.lastCheckTime = new Date();
      }
    } catch (error) {
      console.error('❌ Error polling alerts:', error);
    }
  }

  private async sendToMattermost(alert: any) {
    if (!this.mattermostWebhook) {
      console.warn('⚠️  Mattermost webhook not configured');
      return;
    }

    const color = {
      high: '#FF0000',
      medium: '#FFA500',
      low: '#0000FF'
    }[alert.severity] || '#808080';

    const icon = {
      high: '🚨',
      medium: '⚠️',
      low: 'ℹ️'
    }[alert.severity] || '📢';

    try {
      await axios.post(this.mattermostWebhook, {
        text: `${icon} **Security Alert: ${alert.rule_name}**`,
        username: 'HMA Security Bot',
        icon_emoji: ':shield:',
        attachments: [{
          color,
          title: alert.rule_name,
          text: alert.description,
          fields: [
            {
              short: true,
              title: 'Severity',
              value: alert.severity.toUpperCase()
            },
            {
              short: true,
              title: 'Risk Score',
              value: alert.risk_score.toString()
            },
            {
              short: true,
              title: 'Alerts',
              value: alert.alert_count.toString()
            },
            {
              short: true,
              title: 'Time',
              value: alert.triggered_at
            }
          ]
        }],
        props: {
          card: JSON.stringify({
            header: 'View in Kibana',
            actions: [{
              name: 'Open',
              integration: {
                url: alert.kibana_url
              }
            }]
          })
        }
      });

      console.log(`✅ Alert sent to Mattermost: ${alert.rule_name}`);
    } catch (error) {
      console.error('❌ Error sending to Mattermost:', error.message);
    }
  }
}

// Start the service
const alertService = new AlertPollingService();
alertService.start();
```

---

## Step 4: Add to Backend Startup

```typescript
// /hma-academy-brain/src/index.ts

import { AlertPollingService } from './services/alertPollingService';

class Server {
  // ... existing code ...

  async start() {
    // ... existing startup code ...

    // Start alert polling service
    if (process.env.ENABLE_ALERT_POLLING === 'true') {
      const alertService = new AlertPollingService();
      alertService.start();
      console.log('✅ Alert polling service initialized');
    }

    // ... rest of startup code ...
  }
}
```

---

## Step 5: Add Environment Variables

```bash
# /hma-academy-brain/.env

# Alert Polling Configuration
ENABLE_ALERT_POLLING=true
MATTERMOST_WEBHOOK_URL=http://hma_mattermost:8065/hooks/YOUR_WEBHOOK_ID
ELASTIC_PASSWORD=HMA_Elastic_Dev_Pass_2025!
```

---

## Step 6: Install Dependencies

```bash
cd /home/xbyooki/projects/hma-academy-brain
npm install @elastic/elasticsearch
```

---

## Alternative: Direct Database Trigger

For real-time alerts (no polling delay), use PostgreSQL triggers:

```sql
-- Create alerts table
CREATE TABLE security_alerts (
  id SERIAL PRIMARY KEY,
  rule_id VARCHAR(255),
  rule_name VARCHAR(255),
  severity VARCHAR(50),
  risk_score INTEGER,
  description TEXT,
  alert_count INTEGER,
  triggered_at TIMESTAMP DEFAULT NOW(),
  sent_to_mattermost BOOLEAN DEFAULT FALSE,
  kibana_url TEXT
);

-- Create function to notify on insert
CREATE OR REPLACE FUNCTION notify_new_alert()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('new_security_alert', row_to_json(NEW)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER alert_notify_trigger
AFTER INSERT ON security_alerts
FOR EACH ROW
EXECUTE FUNCTION notify_new_alert();
```

Then listen for notifications in backend:

```typescript
// Listen for PostgreSQL NOTIFY events
databaseService.query('LISTEN new_security_alert');

databaseService.on('notification', async (msg) => {
  if (msg.channel === 'new_security_alert') {
    const alert = JSON.parse(msg.payload);
    await sendToMattermost(alert);
  }
});
```

---

## Comparison: Polling vs Triggers

| Method | Pros | Cons |
|--------|------|------|
| **ES Polling** | Simple, no DB changes | 1-minute delay |
| **DB Triggers** | Real-time, instant | Requires schema changes |
| **Hybrid** | Use DB for critical alerts, ES for others | More complex |

---

## Testing

### 1. Create Index Connector
```bash
# Via Kibana UI or API (see Step 1)
```

### 2. Attach to Rule
```bash
# Via Kibana UI (see Step 2)
```

### 3. Generate Test Alert
```bash
cd /home/xbyooki/projects/hma-infra/security
./test-security-rules.sh failed-logins
```

### 4. Check Alert Index
```bash
# Wait 5-10 minutes for rule to execute
curl -u elastic:HMA_Elastic_Dev_Pass_2025! \
  "http://localhost:9200/hma-security-alerts/_search?pretty"
```

### 5. Verify Backend Processing
```bash
# Check backend logs
docker logs hma-academy-brain | grep -i "alert"
```

### 6. Check Mattermost
```bash
# Should see alert in #security-alerts channel
```

---

## Benefits of This Approach

✅ **No License Costs** - Uses only free Elastic connectors
✅ **Full Control** - Custom processing logic in backend
✅ **Flexible** - Can send to multiple destinations (Mattermost, email, SMS, etc.)
✅ **Auditable** - All alerts stored in Elasticsearch
✅ **Extendable** - Add custom logic, filtering, routing
✅ **Database Integration** - Can correlate with user data, store in PostgreSQL

---

## Future Enhancements

1. **Alert Deduplication** - Don't spam for repeated alerts
2. **Custom Routing** - High severity to PagerDuty, low to email
3. **Alert Correlation** - Group related alerts
4. **Admin Dashboard** - View alerts in HMA admin portal
5. **User Notifications** - Notify affected users via email
6. **Slack/Discord** - Add additional webhook destinations
7. **SMS Alerts** - Via Twilio for critical alerts

---

## Summary

Since Elastic Basic doesn't support webhook/email connectors, we:

1. ✅ Use **Index connector** (FREE) to write alerts to ES
2. ✅ Poll ES from **backend service** (1-minute interval)
3. ✅ Forward to **Mattermost webhook** (self-hosted, FREE)
4. ✅ Store in **PostgreSQL** for audit trail (optional)
5. ✅ Display in **admin dashboard** (future)

This gives us the same functionality as paid connectors, but with more flexibility and no recurring costs!

---

**Next Steps**:
1. Create index connector in Kibana
2. Attach to security rules
3. Implement polling service in backend
4. Test with simulated alerts
5. Deploy and monitor

---

**Documentation**:
- Index Connector: https://www.elastic.co/guide/en/kibana/current/index-action-type.html
- Elasticsearch Node.js Client: https://www.elastic.co/guide/en/elasticsearch/client/javascript-api/current/index.html
