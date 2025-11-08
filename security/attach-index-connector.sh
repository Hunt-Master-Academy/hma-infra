#!/bin/bash
# [20251108-ALERTS-014] Attach Index connector to all HMA security rules

KIBANA_URL="http://localhost:5601"
KIBANA_USER="elastic"
KIBANA_PASS="HMA_Elastic_Dev_Pass_2025!"
CONNECTOR_ID="cb356015-1d2c-4cd9-9ac0-72681c7b1d6e"  # HMA Security Alerts Index connector

echo "🔧 Attaching Index connector to HMA security rules..."
echo ""

# Get all HMA rule IDs
RULE_IDS=$(curl -s -u ${KIBANA_USER}:${KIBANA_PASS} \
  -X GET "${KIBANA_URL}/api/detection_engine/rules/_find?per_page=100" \
  -H 'kbn-xsrf: true' | jq -r '.data[] | select(.name | startswith("HMA -")) | .id')

if [ -z "$RULE_IDS" ]; then
  echo "❌ No HMA rules found"
  exit 1
fi

echo "Found $(echo "$RULE_IDS" | wc -l) HMA rules"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

for RULE_ID in $RULE_IDS; do
  # Get rule name for display
  RULE_NAME=$(curl -s -u ${KIBANA_USER}:${KIBANA_PASS} \
    -X GET "${KIBANA_URL}/api/detection_engine/rules?id=${RULE_ID}" \
    -H 'kbn-xsrf: true' | jq -r '.name')
  
  echo "📌 Configuring: $RULE_NAME"
  
  # Add Index connector action to rule
  RESPONSE=$(curl -s -u ${KIBANA_USER}:${KIBANA_PASS} \
    -X PATCH "${KIBANA_URL}/api/detection_engine/rules" \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' \
    -d @- <<EOF
{
  "id": "${RULE_ID}",
  "throttle": "rule",
  "actions": [
    {
      "group": "default",
      "action_type_id": ".index",
      "id": "${CONNECTOR_ID}",
      "params": {
        "documents": [
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
        ]
      }
    }
  ]
}
EOF
  )
  
  if echo "$RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
    echo "  ✅ Attached to: $RULE_NAME"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "  ❌ Failed: $RULE_NAME"
    echo "     Error: $(echo "$RESPONSE" | jq -r '.message // .error')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Successfully configured: $SUCCESS_COUNT rules"
echo "❌ Failed: $FAIL_COUNT rules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
