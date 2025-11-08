#!/bin/bash
# [20251108-SECURITY-003] Configure alert connectors and actions for Elastic Security

set -e

KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ELASTIC_USER="${ELASTIC_USER:-elastic}"
ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-HMA_Elastic_Dev_Pass_2025!}"

# Email configuration (override these with your actual SMTP settings)
EMAIL_USER="${EMAIL_USER:-}"
EMAIL_PASSWORD="${EMAIL_PASSWORD:-}"

# Microsoft Teams webhook URL (create incoming webhook in Teams channel)
TEAMS_WEBHOOK_URL="${TEAMS_WEBHOOK_URL:-}"

echo "🔌 Configuring Alert Connectors for Elastic Security..."
echo "📍 Kibana: $KIBANA_URL"
echo ""

# Check if Kibana is accessible
if ! curl -s -f -u "$ELASTIC_USER:$ELASTIC_PASSWORD" "$KIBANA_URL/api/status" > /dev/null; then
    echo "❌ Error: Cannot connect to Kibana at $KIBANA_URL"
    exit 1
fi

# Function to create or update connector
create_connector() {
    local connector_name="$1"
    local connector_type="$2"
    local config_json="$3"
    
    echo -n "  Creating connector: $connector_name ... "
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
        -X POST "$KIBANA_URL/api/actions/connector" \
        -H 'kbn-xsrf: true' \
        -H 'Content-Type: application/json' \
        -d "$config_json")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        CONNECTOR_ID=$(echo "$BODY" | jq -r '.id')
        echo "✅ Created (ID: $CONNECTOR_ID)"
        echo "$CONNECTOR_ID"
        return 0
    else
        echo "⚠️  Failed (HTTP $HTTP_CODE)"
        echo "     Error: $(echo "$BODY" | jq -r '.message // .error // "Unknown error"')" >&2
        echo ""
        return 1
    fi
}

# Function to attach action to rule
attach_action_to_rule() {
    local rule_name="$1"
    local connector_id="$2"
    local action_params="$3"
    
    # Find rule ID by name
    RULE_ID=$(curl -s -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
        "$KIBANA_URL/api/detection_engine/rules/_find?filter=alert.attributes.name:\"$rule_name\"" \
        -H 'kbn-xsrf: true' | jq -r '.data[0].id')
    
    if [ -z "$RULE_ID" ] || [ "$RULE_ID" = "null" ]; then
        echo "  ⚠️  Rule not found: $rule_name"
        return 1
    fi
    
    echo -n "  Attaching action to: $rule_name ... "
    
    # Update rule with action
    RULE_UPDATE=$(cat <<EOF
{
  "actions": [
    {
      "group": "default",
      "id": "$connector_id",
      "params": $action_params,
      "action_type_id": "$(echo "$action_params" | jq -r '.action_type_id // ".email"')"
    }
  ]
}
EOF
)
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
        -X PATCH "$KIBANA_URL/api/detection_engine/rules?id=$RULE_ID" \
        -H 'kbn-xsrf: true' \
        -H 'Content-Type: application/json' \
        -d "$RULE_UPDATE")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅"
        return 0
    else
        echo "⚠️  Failed"
        return 1
    fi
}

echo "📧 Email Connector Configuration"
echo "================================"

if [ -z "$EMAIL_USER" ] || [ -z "$EMAIL_PASSWORD" ]; then
    echo "⚠️  Email credentials not provided. Skipping email connector."
    echo "   Set EMAIL_USER and EMAIL_PASSWORD environment variables to enable."
    echo ""
    EMAIL_CONNECTOR_ID=""
else
    EMAIL_CONFIG=$(cat <<EOF
{
  "name": "HMA Security Alerts - Email",
  "connector_type_id": ".email",
  "config": {
    "service": "other",
    "from": "security@huntmasteracademy.com",
    "host": "smtp.hostinger.com",
    "port": 465,
    "secure": true,
    "hasAuth": true
  },
  "secrets": {
    "user": "$EMAIL_USER",
    "password": "$EMAIL_PASSWORD"
  }
}
EOF
)
    
    EMAIL_CONNECTOR_ID=$(create_connector "HMA Email Alerts" ".email" "$EMAIL_CONFIG")
    echo ""
fi

echo "💬 Microsoft Teams Connector Configuration"
echo "=========================================="

if [ -z "$TEAMS_WEBHOOK_URL" ]; then
    echo "⚠️  Teams webhook URL not provided. Creating example configuration."
    echo "   To enable Teams notifications:"
    echo "   1. Go to your Teams channel → Connectors → Incoming Webhook"
    echo "   2. Copy the webhook URL"
    echo "   3. Set TEAMS_WEBHOOK_URL environment variable"
    echo "   4. Run this script again"
    echo ""
    
    # Create a test connector with placeholder URL for documentation
    TEAMS_CONFIG=$(cat <<EOF
{
  "name": "HMA Security Alerts - Teams (Not Configured)",
  "connector_type_id": ".teams",
  "config": {},
  "secrets": {
    "webhookUrl": "https://outlook.office.com/webhook/PLACEHOLDER"
  }
}
EOF
)
    
    TEAMS_CONNECTOR_ID=$(create_connector "HMA Teams Alerts (Placeholder)" ".teams" "$TEAMS_CONFIG" || echo "")
    echo ""
else
    TEAMS_CONFIG=$(cat <<EOF
{
  "name": "HMA Security Alerts - Microsoft Teams",
  "connector_type_id": ".teams",
  "config": {},
  "secrets": {
    "webhookUrl": "$TEAMS_WEBHOOK_URL"
  }
}
EOF
)
    
    TEAMS_CONNECTOR_ID=$(create_connector "HMA Teams Alerts" ".teams" "$TEAMS_CONFIG")
    echo ""
fi

echo "📎 Attaching Actions to Detection Rules"
echo "========================================"

if [ -n "$EMAIL_CONNECTOR_ID" ]; then
    echo "📧 Attaching email notifications to high-severity rules:"
    
    HIGH_SEVERITY_EMAIL_PARAMS=$(cat <<'EOF'
{
  "to": ["security@huntmasteracademy.com", "devops@huntmasteracademy.com"],
  "subject": "🚨 HMA Security Alert [HIGH]: {{context.rule.name}}",
  "message": "**Security Alert Triggered**\n\n**Rule**: {{context.rule.name}}\n**Severity**: HIGH\n**Time**: {{date}}\n\n**Description**: {{context.rule.description}}\n\n**Alerts**: {{state.signals_count}}\n\n**View Details**: {{context.kibanaBaseUrl}}/app/security/alerts\n\n---\nHunt Master Academy Security Monitoring"
}
EOF
)
    
    attach_action_to_rule "HMA - Multiple Failed Admin Login Attempts" "$EMAIL_CONNECTOR_ID" "$HIGH_SEVERITY_EMAIL_PARAMS"
    attach_action_to_rule "HMA - Unauthorized Admin Access Attempt" "$EMAIL_CONNECTOR_ID" "$HIGH_SEVERITY_EMAIL_PARAMS"
    
    echo ""
    echo "📧 Attaching email notifications to medium-severity rules:"
    
    MEDIUM_SEVERITY_EMAIL_PARAMS=$(cat <<'EOF'
{
  "to": ["security@huntmasteracademy.com"],
  "subject": "⚠️ HMA Security Alert [MEDIUM]: {{context.rule.name}}",
  "message": "**Security Alert**\n\n**Rule**: {{context.rule.name}}\n**Severity**: MEDIUM\n**Time**: {{date}}\n\n**Description**: {{context.rule.description}}\n\n**View Details**: {{context.kibanaBaseUrl}}/app/security/alerts"
}
EOF
)
    
    attach_action_to_rule "HMA - Failed Authentication Spike" "$EMAIL_CONNECTOR_ID" "$MEDIUM_SEVERITY_EMAIL_PARAMS"
    attach_action_to_rule "HMA - Suspicious Credit Manipulation" "$EMAIL_CONNECTOR_ID" "$MEDIUM_SEVERITY_EMAIL_PARAMS"
    attach_action_to_rule "HMA - Database Connection Failures" "$EMAIL_CONNECTOR_ID" "$MEDIUM_SEVERITY_EMAIL_PARAMS"
    
    echo ""
fi

if [ -n "$TEAMS_CONNECTOR_ID" ] && [ "$TEAMS_WEBHOOK_URL" != "https://outlook.office.com/webhook/PLACEHOLDER" ]; then
    echo "💬 Attaching Teams notifications to high-severity rules:"
    
    HIGH_SEVERITY_TEAMS_PARAMS=$(cat <<'EOF'
{
  "message": "🚨 **HMA Security Alert [HIGH]**\n\n**Rule**: {{context.rule.name}}\n**Time**: {{date}}\n**Description**: {{context.rule.description}}\n\n[View in Kibana]({{context.kibanaBaseUrl}}/app/security/alerts)"
}
EOF
)
    
    attach_action_to_rule "HMA - Multiple Failed Admin Login Attempts" "$TEAMS_CONNECTOR_ID" "$HIGH_SEVERITY_TEAMS_PARAMS"
    attach_action_to_rule "HMA - Unauthorized Admin Access Attempt" "$TEAMS_CONNECTOR_ID" "$HIGH_SEVERITY_TEAMS_PARAMS"
    
    echo ""
fi

echo "✅ Alert connector configuration complete!"
echo ""
echo "📊 Summary:"
echo "   Email connector: ${EMAIL_CONNECTOR_ID:-Not configured}"
echo "   Teams connector: ${TEAMS_CONNECTOR_ID:-Not configured}"
echo ""
echo "🔗 Manage connectors: $KIBANA_URL/app/management/insightsAndAlerting/connectors"
echo "🔗 View alerts: $KIBANA_URL/app/security/alerts"
echo ""
echo "📝 To configure email/Teams later, set environment variables and re-run:"
echo "   EMAIL_USER=your-email@gmail.com EMAIL_PASSWORD=your-app-password \\"
echo "   TEAMS_WEBHOOK_URL=your-webhook-url \\"
echo "   $0"
