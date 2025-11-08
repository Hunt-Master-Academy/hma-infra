# Mattermost Incoming Webhook Setup

## Step 1: Log into Mattermost

1. Open Mattermost: http://localhost:8065
2. Create account or log in with existing credentials
3. Create a team (or use existing team)

## Step 2: Create Incoming Webhook

### Via UI:
1. Click **Main Menu** (☰ top-left) → **Integrations**
2. Click **Incoming Webhooks**
3. Click **Add Incoming Webhook**
4. Configure:
   - **Title**: HMA Security Alerts
   - **Description**: Receives security alerts from Elastic Stack
   - **Channel**: Create `#security-alerts` channel or select existing
   - **Username**: HMA Security Bot
   - **Icon**: `:shield:` (optional)
   - **Lock to channel**: Enabled (optional)
5. Click **Save**
6. Copy the **Webhook URL** (looks like: `http://localhost:8065/hooks/abc123xyz`)

### Via API (Advanced):

```bash
# Get auth token first (login to Mattermost)
MM_TOKEN="your_auth_token_here"

# Create incoming webhook
curl -X POST http://localhost:8065/api/v4/hooks/incoming \
  -H "Authorization: Bearer $MM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "channel_id": "channel_id_here",
    "display_name": "HMA Security Alerts",
    "description": "Receives security alerts from Elastic Stack"
  }'
```

## Step 3: Add to Environment Variables

Add webhook URL to `/home/xbyooki/projects/hma-academy-brain/.env`:

```bash
# Alert Polling Configuration
ENABLE_ALERT_POLLING=true
MATTERMOST_WEBHOOK_URL=http://hma_mattermost:8065/hooks/YOUR_WEBHOOK_ID
ELASTICSEARCH_URL=http://hma_elasticsearch:9200
ELASTIC_PASSWORD=HMA_Elastic_Dev_Pass_2025!
ALERT_POLL_INTERVAL=60000  # Poll every 60 seconds (1 minute)
```

**⚠️ IMPORTANT**: Use Docker service name `hma_mattermost` not `localhost` (for container-to-container communication)

## Step 4: Update Docker Compose

Add environment variables to `docker-compose.yml`:

```yaml
hma-academy-brain:
  # ... existing config ...
  environment:
    # ... existing vars ...
    # [20251108-ALERTS-015] Alert polling configuration
    - ENABLE_ALERT_POLLING=true
    - MATTERMOST_WEBHOOK_URL=http://hma_mattermost:8065/hooks/YOUR_WEBHOOK_ID
    - ELASTICSEARCH_URL=http://hma_elasticsearch:9200
    - ELASTIC_PASSWORD=HMA_Elastic_Dev_Pass_2025!
    - ALERT_POLL_INTERVAL=60000
```

## Step 5: Restart Backend

```bash
cd /home/xbyooki/projects/hma-infra/docker
docker-compose restart hma-academy-brain

# Check logs for alert service startup
docker logs hma-academy-brain | grep -i "alert"
```

You should see:
```
📊 Alert Polling Service configured:
  - Elasticsearch: http://hma_elasticsearch:9200
  - Poll interval: 60000ms
  - Mattermost webhook: configured
✅ Alert polling service initialized
```

## Step 6: Test Webhook (Optional)

Test webhook manually before running full flow:

```bash
WEBHOOK_URL="http://localhost:8065/hooks/YOUR_WEBHOOK_ID"

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "🚨 **Test Alert: Security Alert System**",
    "username": "HMA Security Bot",
    "icon_emoji": ":shield:",
    "attachments": [{
      "color": "#FF0000",
      "title": "Test Security Alert",
      "text": "This is a test message from the HMA Alert Polling Service",
      "fields": [
        {"short": true, "title": "Severity", "value": "HIGH"},
        {"short": true, "title": "Risk Score", "value": "75"},
        {"short": true, "title": "Status", "value": "Testing"},
        {"short": true, "title": "Time", "value": "'"$(date)"'"}
      ]
    }]
  }'
```

If successful, you'll see the test message in #security-alerts channel.

## Troubleshooting

### Webhook URL format
- ✅ Correct: `http://hma_mattermost:8065/hooks/abc123xyz` (in backend container)
- ❌ Wrong: `http://localhost:8065/hooks/abc123xyz` (won't work from container)

### Channel not found
- Create `#security-alerts` channel in Mattermost before configuring webhook
- Or use an existing channel

### Webhook disabled
- Check Mattermost System Console → Integrations → Enable Incoming Webhooks
- Default is enabled in Mattermost

### Authentication errors
- Webhooks don't require authentication
- If getting 401/403, check webhook ID is correct

### Container networking
- Backend must use `hma_mattermost` hostname (Docker service name)
- From host machine, use `localhost:8065`
- Both are the same service, different network contexts

## Next Steps

After webhook is configured and backend restarted:

1. Generate test security alerts using `/hma-infra/security/test-security-rules.sh`
2. Wait 5-10 minutes for rules to execute
3. Check Elasticsearch for alerts: `curl http://localhost:9200/hma-security-alerts/_search?pretty`
4. Check backend logs: `docker logs -f hma-academy-brain | grep -i alert`
5. Check Mattermost #security-alerts channel for notifications

---

**Documentation**: 
- Mattermost Webhooks: https://docs.mattermost.com/developer/webhooks-incoming.html
- Alert Polling Service: `/hma-academy-brain/src/services/alertPollingService.ts`
- Free Alert Solution: `/hma-infra/security/FREE_ALERT_SOLUTION.md`
