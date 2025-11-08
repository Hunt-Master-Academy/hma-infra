#!/bin/bash
# [20251108-SECURITY-001] Import HMA custom detection rules into Elastic Security

set -e

KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ELASTIC_USER="${ELASTIC_USER:-elastic}"
ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-HMA_Elastic_Dev_Pass_2025!}"
RULES_FILE="${1:-/home/xbyooki/projects/hma-infra/security/detection-rules.json}"

echo "🔐 Importing HMA detection rules to Elastic Security..."
echo "📍 Kibana: $KIBANA_URL"
echo "📄 Rules file: $RULES_FILE"

# Check if Kibana is accessible
if ! curl -s -f -u "$ELASTIC_USER:$ELASTIC_PASSWORD" "$KIBANA_URL/api/status" > /dev/null; then
    echo "❌ Error: Cannot connect to Kibana at $KIBANA_URL"
    exit 1
fi

# Initialize detection engine if not already done
echo "🔧 Initializing detection engine..."
curl -s -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
    -X POST "$KIBANA_URL/api/detection_engine/index" \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' > /dev/null

# Import each rule
echo "📥 Importing detection rules..."
RULE_COUNT=0
SUCCESS_COUNT=0
FAILED_COUNT=0

# Read rules from JSON file
RULES=$(jq -c '.rules[]' "$RULES_FILE")

while IFS= read -r rule; do
    RULE_COUNT=$((RULE_COUNT + 1))
    RULE_NAME=$(echo "$rule" | jq -r '.name')
    
    echo -n "  [$RULE_COUNT] $RULE_NAME ... "
    
    # Transform rule to Kibana detection rule format
    KIBANA_RULE=$(cat <<EOF
{
  "name": $(echo "$rule" | jq '.name'),
  "description": $(echo "$rule" | jq '.description'),
  "risk_score": $(echo "$rule" | jq '.risk_score'),
  "severity": $(echo "$rule" | jq '.severity'),
  "type": "query",
  "language": "lucene",
  "query": $(echo "$rule" | jq '.query'),
  "interval": $(echo "$rule" | jq -r '.interval // "5m"' | jq -R .),
  "from": $(echo "$rule" | jq -r '.from // "now-6m"' | jq -R .),
  "to": "now",
  "enabled": true,
  "tags": $(echo "$rule" | jq '.tags'),
  "actions": []
}
EOF
)
    
    # Create rule via API
    RESPONSE=$(curl -s -w "\n%{http_code}" -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
        -X POST "$KIBANA_URL/api/detection_engine/rules" \
        -H 'kbn-xsrf: true' \
        -H 'Content-Type: application/json' \
        -d "$KIBANA_RULE")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "✅ Created"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif echo "$BODY" | grep -q "already exists"; then
        echo "⚠️  Already exists"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "❌ Failed (HTTP $HTTP_CODE)"
        echo "     Error: $(echo "$BODY" | jq -r '.message // .error // "Unknown error"')"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done <<< "$RULES"

echo ""
echo "📊 Import Summary:"
echo "   Total rules: $RULE_COUNT"
echo "   Successful: $SUCCESS_COUNT"
echo "   Failed: $FAILED_COUNT"

if [ $FAILED_COUNT -eq 0 ]; then
    echo "✅ All detection rules imported successfully!"
    echo "🔗 View in Kibana: $KIBANA_URL/app/security/rules"
    exit 0
else
    echo "⚠️  Some rules failed to import. Check errors above."
    exit 1
fi
